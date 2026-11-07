# Manticore configuration for Gazelle, adapted from the project's sphinx.conf.
# Legacy Sphinx-2.x-only directives (enable_star, dict, charset_type,
# phrase_boundary, infix_fields, compat_sphinxql_magics) are dropped; Manticore
# applies sane defaults (utf-8, infix search via min_infix_len).
# __SQL_USER__ / __SQL_PASS__ are substituted from the environment at startup.

source connect {
    type        = mysql
    sql_host    = db
    sql_port    = 3306
    sql_user    = __SQL_USER__
    sql_pass    = __SQL_PASS__
    sql_db      = gazelle
}

source torrents_base : connect {
    sql_attr_uint   = groupid
    sql_attr_uint   = time
    sql_attr_uint   = categoryid
    sql_attr_uint   = releasetype
    sql_attr_bigint = size
    sql_attr_uint   = snatched
    sql_attr_uint   = seeders
    sql_attr_uint   = leechers
    sql_attr_uint   = logscore
    sql_attr_uint   = groupyear
    sql_attr_bool   = scene
    sql_attr_bool   = vanityhouse
    sql_attr_bool   = haslog
    sql_attr_bool   = hascue
    sql_attr_uint   = freetorrent
}

source torrents : torrents_base {
    sql_query_pre = SET group_concat_max_len = 101400
    sql_query_pre = SET @starttime = NOW()
    sql_query_pre = REPLACE INTO sphinx_index_last_pos VALUES ('torrents', UNIX_TIMESTAMP(@starttime))
    sql_query_pre = TRUNCATE sphinx_tg
    sql_query_pre = INSERT INTO sphinx_tg \
        (id, name, tags, year, rlabel, cnumber, catid, reltype, vanityhouse) \
        SELECT id, name, taglist, year, recordlabel, cataloguenumber, \
            categoryid, releasetype, vanityhouse \
        FROM torrents_group WHERE time < @starttime
    sql_query_pre = TRUNCATE sphinx_t
    sql_query_pre = INSERT INTO sphinx_t \
        (id, gid, size, snatched, seeders, leechers, time, logscore, scene, \
            haslog, hascue, freetorrent, description, media, format, encoding, \
            remyear, remtitle, remrlabel, remcnumber, filelist, uid, remident) \
        SELECT ID, GroupID, Size, Snatched, Seeders, Leechers, UNIX_TIMESTAMP(Time), \
            LogScore, CAST(Scene AS CHAR), CAST(HasLog AS CHAR), \
            CAST(HasCue AS CHAR), CAST(FreeTorrent AS CHAR), Description, \
            Media, Format, Encoding, RemasterYear, RemasterTitle, \
            RemasterRecordLabel, RemasterCatalogueNumber, FileList, UserID, \
            CRC32(CONCAT_WS(' ', Media, RemasterYear, RemasterTitle, \
                RemasterRecordLabel, RemasterCatalogueNumber)) \
        FROM torrents WHERE Time < @starttime
    sql_query_pre = TRUNCATE sphinx_a
    sql_query_pre = INSERT INTO sphinx_a (gid, aname) \
        SELECT GroupID, GROUP_CONCAT(aa.Name SEPARATOR ' ') \
        FROM torrents_artists AS ta JOIN artists_alias AS aa USING(AliasID) \
        WHERE Importance IN ('1','3','4','5','6') GROUP BY ta.groupid ORDER BY NULL
    sql_query = SELECT t.id, g.id AS groupid, g.name AS groupname, \
            tags AS taglist, year AS yearfulltext, \
            rlabel AS recordlabel, cnumber AS cataloguenumber, \
            catid AS categoryid, t.time, reltype AS releasetype, \
            size, snatched, seeders, leechers, logscore, \
            year AS groupyear, \
            scene, vanityhouse, haslog, hascue, freetorrent, description, \
            media, format, encoding, remyear AS remasteryear, \
            remtitle AS remastertitle, remrlabel AS remasterrecordlabel, \
            remcnumber AS remastercataloguenumber, \
            REPLACE(filelist, '_', ' ') AS filelist \
        FROM sphinx_t AS t JOIN sphinx_tg AS g ON t.gid = g.id
    sql_joined_field = artistname from query; \
        SELECT t.id, aname FROM sphinx_a JOIN sphinx_t AS t USING(gid) ORDER BY t.id ASC;
}

index torrents {
    source        = torrents
    path          = /var/lib/manticore/torrents
    morphology    = none
    min_word_len  = 2
    min_infix_len = 3
}

source requests_base : connect {
    sql_attr_uint = UserID
    sql_attr_uint = TimeAdded
    sql_attr_uint = LastVote
    sql_attr_uint = CategoryID
    sql_attr_uint = groupyear
    sql_attr_uint = ReleaseType
    sql_attr_uint = FillerID
    sql_attr_uint = TorrentID
    sql_attr_uint = TimeFilled
    sql_attr_uint = Visible
    sql_attr_uint = Votes
    sql_attr_uint = Bounty
}

source requests : requests_base {
    sql_query_pre = TRUNCATE TABLE sphinx_requests
    sql_query_pre = SET group_concat_max_len = 10140
    sql_query_pre = SET @starttime = NOW()
    sql_query_pre = REPLACE INTO sphinx_index_last_pos VALUES ('requests', UNIX_TIMESTAMP(@starttime))
    sql_query_pre = INSERT INTO sphinx_requests ( \
                ID, UserID, TimeAdded, LastVote, CategoryID, Title, \
                Year, ReleaseType, RecordLabel, CatalogueNumber, \
                BitrateList, FormatList, MediaList, LogCue, FillerID, \
                TorrentID, TimeFilled, Visible, Votes, Bounty ) \
            SELECT r.ID, r.UserID, UNIX_TIMESTAMP(TimeAdded), \
                UNIX_TIMESTAMP(LastVote), CategoryID, Title, Year, \
                ReleaseType, RecordLabel, CatalogueNumber, BitrateList, \
                FormatList, MediaList, LogCue, FillerID, TorrentID, \
                UNIX_TIMESTAMP(TimeFilled), Visible, \
                COUNT(rv.RequestID), SUM(rv.Bounty) >> 10 \
            FROM requests AS r JOIN requests_votes AS rv ON rv.RequestID = r.ID \
            GROUP BY rv.RequestID
    sql_query_pre = INSERT INTO sphinx_requests (ID, ArtistList) \
            SELECT RequestID, GROUP_CONCAT(aa.Name SEPARATOR ' ') \
            FROM requests_artists AS ra \
                JOIN artists_alias AS aa ON aa.AliasID = ra.AliasID \
                JOIN requests AS r ON r.ID = ra.RequestID \
            WHERE TimeAdded <= @starttime GROUP BY r.ID \
            ON DUPLICATE KEY UPDATE ArtistList = VALUES(ArtistList)
    sql_query = SELECT ID, UserID, TimeAdded, LastVote, CategoryID, Title, \
                Year AS groupyear, ArtistList, ReleaseType, RecordLabel, CatalogueNumber, \
                BitrateList, FormatList, MediaList, LogCue, FillerID, \
                TorrentID, TimeFilled, Visible, Votes, Bounty, \
                Year AS YearFullText \
            FROM sphinx_requests
    sql_joined_field = taglist from query; \
        SELECT rt.RequestID, REPLACE(t.Name, '.', '_') \
        FROM requests_tags AS rt JOIN tags AS t ON TagID = ID \
        ORDER BY requestid ASC;
    sql_attr_multi = uint Voter from query; \
        SELECT RequestID AS ID, UserID FROM requests_votes
    sql_attr_multi = uint Bookmarker from query; \
        SELECT RequestID AS ID, UserID FROM bookmarks_requests
}

index requests {
    source        = requests
    path          = /var/lib/manticore/requests
    morphology    = none
    min_word_len  = 2
    min_infix_len = 3
}

indexer {
    mem_limit = 64M
}

searchd {
    listen     = 9306:mysql
    listen     = 9312
    log        = /var/log/manticore/searchd.log
    query_log  = /var/log/manticore/query.log
    pid_file   = /var/run/manticore/searchd.pid
    binlog_path =
}
