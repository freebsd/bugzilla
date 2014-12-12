-- SET SCHEMA 'whatever';

BEGIN;
    DELETE FROM audit_log;
    UPDATE attach_data SET thedata=E'test';
    UPDATE attachments SET description='test';
    UPDATE bugs SET short_desc=concat('bug desc', bug_id);
    UPDATE bugs SET alias=concat('bug alias', bug_id)
        WHERE alias IS NOT NULL;
    UPDATE bugs_activity set added='test' WHERE fieldid IN (
        SELECT id from fielddefs WHERE name NOT IN ('bug_id',
            'classification', 'product', 'version', 'rep_platform',
            'op_sys', 'bug_status', 'status_whiteboard', 'keywords',
            'resolution', 'bug_severity', 'priority', 'component',
            'dependson', 'blocked', 'attachments.mimetype',
            'attachments.ispatch', 'attachments.isobsolete',
            'attachments.isprivate', 'attachments.submitter',
            'target_milestone', 'creation_ts', 'delta_ts',
            'longdescs.isprivate', 'longdescs.count', 'everconfirmed',
            'estimated_time', 'remaining_time', 'deadline',
            'flagtypes.name', 'work_time', 'percentage_complete',
            'owner_idle_time', 'cf_type', 'days_elapsed')
        );
    UPDATE bugs_fulltext SET short_desc='test',
                             comments='test',
                             comments_noprivate='test';
    DELETE FROM login_failure;
    DELETE FROM logincookies;
    UPDATE longdescs set thetext='test';
    DELETE FROM namedqueries_link_in_footer;
    DELETE FROM namedquery_group_map;
    DELETE FROM namedqueries;
    DELETE FROM profile_search;
    DELETE FROM profile_setting;
    -- Set the password to 'qaywsx' as SHA-256
    UPDATE profiles set
        login_name=concat('user', userid, '@test'),
        cryptpassword='{c8401bf91f73f4058a09a192fab1e6283f1c330038e8a0fabceff8f1b551183{SHA-256}',
        realname=concat('User ', userid),
        extern_id=NULL;
    DELETE FROM tokens;
    DELETE FROM whine_queries;
    DELETE FROM whine_schedules;
    DELETE FROM whine_events;
ROLLBACK;
-- replace the ROLLBACK with a COMMIT.
