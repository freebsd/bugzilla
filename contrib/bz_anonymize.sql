SET SCHEMA 'invalid';

DO $$
DECLARE
    reassign integer;
    fbsdids  integer[];
BEGIN
    SELECT userid INTO reassign
        FROM profiles
        WHERE login_name = 'nobody@FreeBSD.org';
    SELECT array_agg(userid) INTO fbsdids
        FROM (
              SELECT userid
              FROM profiles
              WHERE LOWER(login_name) LIKE '%@freebsd.org'
        ) as tmp;


    UPDATE attachments SET submitter_id = reassign WHERE NOT (submitter_id = ANY(fbsdids));
    DELETE FROM audit_log;
    UPDATE bugs SET reporter = reassign WHERE NOT (reporter = ANY(fbsdids));
    UPDATE bugs set assigned_to = reassign WHERE NOT (assigned_to = ANY(fbsdids));
    UPDATE bugs_activity SET who = reassign WHERE NOT (who = ANY(fbsdids));
    DELETE FROM cc;
    DELETE FROM component_cc;
    UPDATE components SET initialowner = reassign WHERE NOT (initialowner = ANY(fbsdids));
    DELETE FROM email_setting;
    UPDATE flags set setter_id = reassign WHERE NOT (setter_id = ANY(fbsdids));
    UPDATE flags set requestee_id = reassign WHERE NOT (requestee_id = ANY(fbsdids));
    DELETE FROM login_failure;
    DELETE FROM logincookies;
    UPDATE longdescs set who = reassign WHERE NOT (who = ANY(fbsdids));
    DELETE FROM namedqueries_link_in_footer;
    DELETE FROM namedquery_group_map;
    DELETE FROM namedqueries;
    DELETE FROM profile_search;
    DELETE FROM profile_setting;
    DELETE FROM profiles_activity;
    DELETE FROM profiles WHERE NOT (userid = ANY(fbsdids));
    UPDATE quips SET userid = reassign WHERE NOT (userid = ANY(fbsdids));
    DELETE FROM reports;
    DELETE FROM series_categories;
    DELETE FROM series_data;
    DELETE FROM series;
    UPDATE tag set user_id = reassign WHERE NOT (user_id = ANY(fbsdids));
    DELETE FROM tokens;
    DELETE FROM user_group_map WHERE NOT (user_id = ANY(fbsdids));
    DELETE FROM watch;
    DELETE FROM whine_schedules;
    DELETE FROM whine_queries;
    DELETE FROM whine_events;
END $$;

