--Upgrade Script for 2.9.3 to 2.10.0
\set eg_version '''2.10.0'''
BEGIN;

INSERT INTO config.upgrade_log (version, applied_to) VALUES ('2.10.0', :eg_version);

SELECT evergreen.upgrade_deps_block_check('0945', :eg_version);

-- run the entire update inside a DO block for managing the logic
-- of whether to recreate the optional reporter views
DO $$
DECLARE
    has_current_circ BOOLEAN;
    has_billing_summary BOOLEAN;
BEGIN

SELECT INTO has_current_circ TRUE FROM pg_views 
    WHERE schemaname = 'reporter' AND viewname = 'classic_current_circ';

SELECT INTO has_billing_summary TRUE FROM pg_views 
    WHERE schemaname = 'reporter' AND 
    viewname = 'classic_current_billing_summary';

DROP VIEW action.all_circulation;
DROP VIEW IF EXISTS reporter.classic_current_circ;
DROP VIEW IF EXISTS reporter.classic_current_billing_summary;
DROP VIEW reporter.demographic;
DROP VIEW auditor.actor_usr_lifecycle;
DROP VIEW action.all_hold_request;

ALTER TABLE actor.usr 
    ALTER dob TYPE DATE USING (dob + '3 hours'::INTERVAL)::DATE;

-- alter the auditor table manually to apply the same
-- dob mangling logic as above.
ALTER TABLE auditor.actor_usr_history 
    ALTER dob TYPE DATE USING (dob + '3 hours'::INTERVAL)::DATE;

-- this recreates auditor.actor_usr_lifecycle
PERFORM auditor.update_auditors();

CREATE VIEW reporter.demographic AS
    SELECT u.id, u.dob,
        CASE
            WHEN u.dob IS NULL THEN 'Adult'::text
            WHEN age(u.dob) > '18 years'::interval THEN 'Adult'::text
            ELSE 'Juvenile'::text
        END AS general_division
    FROM actor.usr u;

CREATE VIEW action.all_circulation AS
         SELECT aged_circulation.id, aged_circulation.usr_post_code,
            aged_circulation.usr_home_ou, aged_circulation.usr_profile,
            aged_circulation.usr_birth_year, aged_circulation.copy_call_number,
            aged_circulation.copy_location, aged_circulation.copy_owning_lib,
            aged_circulation.copy_circ_lib, aged_circulation.copy_bib_record,
            aged_circulation.xact_start, aged_circulation.xact_finish,
            aged_circulation.target_copy, aged_circulation.circ_lib,
            aged_circulation.circ_staff, aged_circulation.checkin_staff,
            aged_circulation.checkin_lib, aged_circulation.renewal_remaining,
            aged_circulation.grace_period, aged_circulation.due_date,
            aged_circulation.stop_fines_time, aged_circulation.checkin_time,
            aged_circulation.create_time, aged_circulation.duration,
            aged_circulation.fine_interval, aged_circulation.recurring_fine,
            aged_circulation.max_fine, aged_circulation.phone_renewal,
            aged_circulation.desk_renewal, aged_circulation.opac_renewal,
            aged_circulation.duration_rule,
            aged_circulation.recurring_fine_rule,
            aged_circulation.max_fine_rule, aged_circulation.stop_fines,
            aged_circulation.workstation, aged_circulation.checkin_workstation,
            aged_circulation.checkin_scan_time, aged_circulation.parent_circ
           FROM action.aged_circulation
UNION ALL
         SELECT DISTINCT circ.id,
            COALESCE(a.post_code, b.post_code) AS usr_post_code,
            p.home_ou AS usr_home_ou, p.profile AS usr_profile,
            date_part('year'::text, p.dob)::integer AS usr_birth_year,
            cp.call_number AS copy_call_number, circ.copy_location,
            cn.owning_lib AS copy_owning_lib, cp.circ_lib AS copy_circ_lib,
            cn.record AS copy_bib_record, circ.xact_start, circ.xact_finish,
            circ.target_copy, circ.circ_lib, circ.circ_staff,
            circ.checkin_staff, circ.checkin_lib, circ.renewal_remaining,
            circ.grace_period, circ.due_date, circ.stop_fines_time,
            circ.checkin_time, circ.create_time, circ.duration,
            circ.fine_interval, circ.recurring_fine, circ.max_fine,
            circ.phone_renewal, circ.desk_renewal, circ.opac_renewal,
            circ.duration_rule, circ.recurring_fine_rule, circ.max_fine_rule,
            circ.stop_fines, circ.workstation, circ.checkin_workstation,
            circ.checkin_scan_time, circ.parent_circ
           FROM action.circulation circ
      JOIN asset.copy cp ON circ.target_copy = cp.id
   JOIN asset.call_number cn ON cp.call_number = cn.id
   JOIN actor.usr p ON circ.usr = p.id
   LEFT JOIN actor.usr_address a ON p.mailing_address = a.id
   LEFT JOIN actor.usr_address b ON p.billing_address = b.id;

CREATE OR REPLACE VIEW action.all_hold_request AS
         SELECT DISTINCT COALESCE(a.post_code, b.post_code) AS usr_post_code,
            p.home_ou AS usr_home_ou, p.profile AS usr_profile,
            date_part('year'::text, p.dob)::integer AS usr_birth_year,
            ahr.requestor <> ahr.usr AS staff_placed, ahr.id, ahr.request_time,
            ahr.capture_time, ahr.fulfillment_time, ahr.checkin_time,
            ahr.return_time, ahr.prev_check_time, ahr.expire_time,
            ahr.cancel_time, ahr.cancel_cause, ahr.cancel_note, ahr.target,
            ahr.current_copy, ahr.fulfillment_staff, ahr.fulfillment_lib,
            ahr.request_lib, ahr.selection_ou, ahr.selection_depth,
            ahr.pickup_lib, ahr.hold_type, ahr.holdable_formats,
                CASE
                    WHEN ahr.phone_notify IS NULL THEN false
                    WHEN ahr.phone_notify = ''::text THEN false
                    ELSE true
                END AS phone_notify,
            ahr.email_notify,
                CASE
                    WHEN ahr.sms_notify IS NULL THEN false
                    WHEN ahr.sms_notify = ''::text THEN false
                    ELSE true
                END AS sms_notify,
            ahr.frozen, ahr.thaw_date, ahr.shelf_time, ahr.cut_in_line,
            ahr.mint_condition, ahr.shelf_expire_time, ahr.current_shelf_lib,
            ahr.behind_desk
           FROM action.hold_request ahr
      JOIN actor.usr p ON ahr.usr = p.id
   LEFT JOIN actor.usr_address a ON p.mailing_address = a.id
   LEFT JOIN actor.usr_address b ON p.billing_address = b.id
UNION ALL
         SELECT aged_hold_request.usr_post_code, aged_hold_request.usr_home_ou,
            aged_hold_request.usr_profile, aged_hold_request.usr_birth_year,
            aged_hold_request.staff_placed, aged_hold_request.id,
            aged_hold_request.request_time, aged_hold_request.capture_time,
            aged_hold_request.fulfillment_time, aged_hold_request.checkin_time,
            aged_hold_request.return_time, aged_hold_request.prev_check_time,
            aged_hold_request.expire_time, aged_hold_request.cancel_time,
            aged_hold_request.cancel_cause, aged_hold_request.cancel_note,
            aged_hold_request.target, aged_hold_request.current_copy,
            aged_hold_request.fulfillment_staff,
            aged_hold_request.fulfillment_lib, aged_hold_request.request_lib,
            aged_hold_request.selection_ou, aged_hold_request.selection_depth,
            aged_hold_request.pickup_lib, aged_hold_request.hold_type,
            aged_hold_request.holdable_formats, aged_hold_request.phone_notify,
            aged_hold_request.email_notify, aged_hold_request.sms_notify,
            aged_hold_request.frozen, aged_hold_request.thaw_date,
            aged_hold_request.shelf_time, aged_hold_request.cut_in_line,
            aged_hold_request.mint_condition,
            aged_hold_request.shelf_expire_time,
            aged_hold_request.current_shelf_lib, aged_hold_request.behind_desk
           FROM action.aged_hold_request;

IF has_current_circ THEN
RAISE NOTICE 'Recreating optional view reporter.classic_current_circ';

CREATE OR REPLACE VIEW reporter.classic_current_circ AS
SELECT	cl.shortname AS circ_lib,
	cl.id AS circ_lib_id,
	circ.xact_start AS xact_start,
	circ_type.type AS circ_type,
	cp.id AS copy_id,
	cp.circ_modifier,
	ol.shortname AS owning_lib_name,
	lm.value AS language,
	lfm.value AS lit_form,
	ifm.value AS item_form,
	itm.value AS item_type,
	sl.name AS shelving_location,
	p.id AS patron_id,
	g.name AS profile_group,
	dem.general_division AS demographic_general_division,
	circ.id AS id,
	cn.id AS call_number,
	cn.label AS call_number_label,
	call_number_dewey(cn.label) AS dewey,
	CASE
		WHEN call_number_dewey(cn.label) ~  E'^[0-9.]+$'
			THEN
				btrim(
					to_char(
						10 * floor((call_number_dewey(cn.label)::float) / 10), '000'
					)
				)
		ELSE NULL
	END AS dewey_block_tens,
	CASE
		WHEN call_number_dewey(cn.label) ~  E'^[0-9.]+$'
			THEN
				btrim(
					to_char(
						100 * floor((call_number_dewey(cn.label)::float) / 100), '000'
					)
				)
		ELSE NULL
	END AS dewey_block_hundreds,
	CASE
		WHEN call_number_dewey(cn.label) ~  E'^[0-9.]+$'
			THEN
				btrim(
					to_char(
						10 * floor((call_number_dewey(cn.label)::float) / 10), '000'
					)
				)
				|| '-' ||
				btrim(
					to_char(
						10 * floor((call_number_dewey(cn.label)::float) / 10) + 9, '000'
					)
				)
		ELSE NULL
	END AS dewey_range_tens,
	CASE
		WHEN call_number_dewey(cn.label) ~  E'^[0-9.]+$'
			THEN
				btrim(
					to_char(
						100 * floor((call_number_dewey(cn.label)::float) / 100), '000'
					)
				)
				|| '-' ||
				btrim(
					to_char(
						100 * floor((call_number_dewey(cn.label)::float) / 100) + 99, '000'
					)
				)
		ELSE NULL
	END AS dewey_range_hundreds,
	hl.id AS patron_home_lib,
	hl.shortname AS patron_home_lib_shortname,
	paddr.county AS patron_county,
	paddr.city AS patron_city,
	paddr.post_code AS patron_zip,
	sc1.stat_cat_entry AS stat_cat_1,
	sc2.stat_cat_entry AS stat_cat_2,
	sce1.value AS stat_cat_1_value,
	sce2.value AS stat_cat_2_value
  FROM	action.circulation circ
	JOIN reporter.circ_type circ_type ON (circ.id = circ_type.id)
	JOIN asset.copy cp ON (cp.id = circ.target_copy)
	JOIN asset.copy_location sl ON (cp.location = sl.id)
	JOIN asset.call_number cn ON (cp.call_number = cn.id)
	JOIN actor.org_unit ol ON (cn.owning_lib = ol.id)
	JOIN metabib.rec_descriptor rd ON (rd.record = cn.record)
	JOIN actor.org_unit cl ON (circ.circ_lib = cl.id)
	JOIN actor.usr p ON (p.id = circ.usr)
	JOIN actor.org_unit hl ON (p.home_ou = hl.id)
	JOIN permission.grp_tree g ON (p.profile = g.id)
	JOIN reporter.demographic dem ON (dem.id = p.id)
	JOIN actor.usr_address paddr ON (paddr.id = p.billing_address)
	LEFT JOIN config.language_map lm ON (rd.item_lang = lm.code)
	LEFT JOIN config.lit_form_map lfm ON (rd.lit_form = lfm.code)
	LEFT JOIN config.item_form_map ifm ON (rd.item_form = ifm.code)
	LEFT JOIN config.item_type_map itm ON (rd.item_type = itm.code)
	LEFT JOIN asset.stat_cat_entry_copy_map sc1 ON (sc1.owning_copy = cp.id AND sc1.stat_cat = 1)
	LEFT JOIN asset.stat_cat_entry sce1 ON (sce1.id = sc1.stat_cat_entry)
	LEFT JOIN asset.stat_cat_entry_copy_map sc2 ON (sc2.owning_copy = cp.id AND sc2.stat_cat = 2)
	LEFT JOIN asset.stat_cat_entry sce2 ON (sce2.id = sc2.stat_cat_entry);
END IF;

IF has_billing_summary THEN
RAISE NOTICE 'Recreating optional view reporter.classic_current_billing_summary';

CREATE OR REPLACE VIEW reporter.classic_current_billing_summary AS
SELECT	x.id AS id,
	x.usr AS usr,
	bl.shortname AS billing_location_shortname,
	bl.name AS billing_location_name,
	x.billing_location AS billing_location,
	c.barcode AS barcode,
	u.home_ou AS usr_home_ou,
	ul.shortname AS usr_home_ou_shortname,
	ul.name AS usr_home_ou_name,
	x.xact_start AS xact_start,
	x.xact_finish AS xact_finish,
	x.xact_type AS xact_type,
	x.total_paid AS total_paid,
	x.total_owed AS total_owed,
	x.balance_owed AS balance_owed,
	x.last_payment_ts AS last_payment_ts,
	x.last_payment_note AS last_payment_note,
	x.last_payment_type AS last_payment_type,
	x.last_billing_ts AS last_billing_ts,
	x.last_billing_note AS last_billing_note,
	x.last_billing_type AS last_billing_type,
	paddr.county AS patron_county,
	paddr.city AS patron_city,
	paddr.post_code AS patron_zip,
	g.name AS profile_group,
	dem.general_division AS demographic_general_division
  FROM	money.open_billable_xact_summary x
	JOIN actor.org_unit bl ON (x.billing_location = bl.id)
	JOIN actor.usr u ON (u.id = x.usr)
	JOIN actor.org_unit ul ON (u.home_ou = ul.id)
	JOIN actor.card c ON (u.card = c.id)
	JOIN permission.grp_tree g ON (u.profile = g.id)
	JOIN reporter.demographic dem ON (dem.id = u.id)
	JOIN actor.usr_address paddr ON (paddr.id = u.billing_address);
END IF;

END $$;

SELECT evergreen.upgrade_deps_block_check('0946', :eg_version);

CREATE OR REPLACE FUNCTION actor.org_unit_ancestor_setting_batch( org_id INT, VARIADIC setting_names TEXT[] ) RETURNS SETOF actor.org_unit_setting AS $$
DECLARE
    setting RECORD;
    setting_name TEXT;
    cur_org INT;
BEGIN
    FOREACH setting_name IN ARRAY setting_names
    LOOP
        cur_org := org_id;
        LOOP
            SELECT INTO setting * FROM actor.org_unit_setting WHERE org_unit = cur_org AND name = setting_name;
            IF FOUND THEN
                RETURN NEXT setting;
                EXIT;
            END IF;
            SELECT INTO cur_org parent_ou FROM actor.org_unit WHERE id = cur_org;
            EXIT WHEN cur_org IS NULL;
        END LOOP;
    END LOOP;
    RETURN;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION actor.org_unit_ancestor_setting_batch( INT, VARIADIC TEXT[] ) IS $$
For each setting name passed, search "up" the org_unit tree until
we find the first occurrence of an org_unit_setting with the given name.
$$;

SELECT evergreen.upgrade_deps_block_check('0947', :eg_version);

CREATE OR REPLACE FUNCTION evergreen.lpad_number_substrings( TEXT, TEXT, INT ) RETURNS TEXT AS $$
    my $string = shift;            # Source string
    my $pad = shift;               # string to fill. Typically '0'. This should be a single character.
    my $len = shift;               # length of resultant padded field

    $string =~ s/([0-9]+)/$pad x ($len - length($1)) . $1/eg;

    return $string;
$$ LANGUAGE PLPERLU;

SELECT evergreen.upgrade_deps_block_check('0951', :eg_version);

ALTER TABLE config.standing_penalty
      ADD COLUMN ignore_proximity INTEGER;

CREATE OR REPLACE FUNCTION action.hold_request_permit_test( pickup_ou INT, request_ou INT, match_item BIGINT, match_user INT, match_requestor INT, retargetting BOOL ) RETURNS SETOF action.matrix_test_result AS $func$
DECLARE
    matchpoint_id        INT;
    user_object        actor.usr%ROWTYPE;
    age_protect_object    config.rule_age_hold_protect%ROWTYPE;
    standing_penalty    config.standing_penalty%ROWTYPE;
    transit_range_ou_type    actor.org_unit_type%ROWTYPE;
    transit_source        actor.org_unit%ROWTYPE;
    item_object        asset.copy%ROWTYPE;
    item_cn_object     asset.call_number%ROWTYPE;
    item_status_object  config.copy_status%ROWTYPE;
    item_location_object    asset.copy_location%ROWTYPE;
    ou_skip              actor.org_unit_setting%ROWTYPE;
    result            action.matrix_test_result;
    hold_test        config.hold_matrix_matchpoint%ROWTYPE;
    use_active_date   TEXT;
    age_protect_date  TIMESTAMP WITH TIME ZONE;
    hold_count        INT;
    hold_transit_prox    INT;
    frozen_hold_count    INT;
    context_org_list    INT[];
    done            BOOL := FALSE;
    hold_penalty TEXT;
    v_pickup_ou ALIAS FOR pickup_ou;
    v_request_ou ALIAS FOR request_ou;
    item_prox INT;
    pickup_prox INT;
BEGIN
    SELECT INTO user_object * FROM actor.usr WHERE id = match_user;
    SELECT INTO context_org_list ARRAY_AGG(id) FROM actor.org_unit_full_path( v_pickup_ou );

    result.success := TRUE;

    -- The HOLD penalty block only applies to new holds.
    -- The CAPTURE penalty block applies to existing holds.
    hold_penalty := 'HOLD';
    IF retargetting THEN
        hold_penalty := 'CAPTURE';
    END IF;

    -- Fail if we couldn't find a user
    IF user_object.id IS NULL THEN
        result.fail_part := 'no_user';
        result.success := FALSE;
        done := TRUE;
        RETURN NEXT result;
        RETURN;
    END IF;

    SELECT INTO item_object * FROM asset.copy WHERE id = match_item;

    -- Fail if we couldn't find a copy
    IF item_object.id IS NULL THEN
        result.fail_part := 'no_item';
        result.success := FALSE;
        done := TRUE;
        RETURN NEXT result;
        RETURN;
    END IF;

    SELECT INTO matchpoint_id action.find_hold_matrix_matchpoint(v_pickup_ou, v_request_ou, match_item, match_user, match_requestor);
    result.matchpoint := matchpoint_id;

    SELECT INTO ou_skip * FROM actor.org_unit_setting WHERE name = 'circ.holds.target_skip_me' AND org_unit = item_object.circ_lib;

    -- Fail if the circ_lib for the item has circ.holds.target_skip_me set to true
    IF ou_skip.id IS NOT NULL AND ou_skip.value = 'true' THEN
        result.fail_part := 'circ.holds.target_skip_me';
        result.success := FALSE;
        done := TRUE;
        RETURN NEXT result;
        RETURN;
    END IF;

    -- Fail if user is barred
    IF user_object.barred IS TRUE THEN
        result.fail_part := 'actor.usr.barred';
        result.success := FALSE;
        done := TRUE;
        RETURN NEXT result;
        RETURN;
    END IF;

    SELECT INTO item_cn_object * FROM asset.call_number WHERE id = item_object.call_number;
    SELECT INTO item_status_object * FROM config.copy_status WHERE id = item_object.status;
    SELECT INTO item_location_object * FROM asset.copy_location WHERE id = item_object.location;

    -- Fail if we couldn't find any matchpoint (requires a default)
    IF matchpoint_id IS NULL THEN
        result.fail_part := 'no_matchpoint';
        result.success := FALSE;
        done := TRUE;
        RETURN NEXT result;
        RETURN;
    END IF;

    SELECT INTO hold_test * FROM config.hold_matrix_matchpoint WHERE id = matchpoint_id;

    IF hold_test.holdable IS FALSE THEN
        result.fail_part := 'config.hold_matrix_test.holdable';
        result.success := FALSE;
        done := TRUE;
        RETURN NEXT result;
    END IF;

    IF item_object.holdable IS FALSE THEN
        result.fail_part := 'item.holdable';
        result.success := FALSE;
        done := TRUE;
        RETURN NEXT result;
    END IF;

    IF item_status_object.holdable IS FALSE THEN
        result.fail_part := 'status.holdable';
        result.success := FALSE;
        done := TRUE;
        RETURN NEXT result;
    END IF;

    IF item_location_object.holdable IS FALSE THEN
        result.fail_part := 'location.holdable';
        result.success := FALSE;
        done := TRUE;
        RETURN NEXT result;
    END IF;

    IF hold_test.transit_range IS NOT NULL THEN
        SELECT INTO transit_range_ou_type * FROM actor.org_unit_type WHERE id = hold_test.transit_range;
        IF hold_test.distance_is_from_owner THEN
            SELECT INTO transit_source ou.* FROM actor.org_unit ou JOIN asset.call_number cn ON (cn.owning_lib = ou.id) WHERE cn.id = item_object.call_number;
        ELSE
            SELECT INTO transit_source * FROM actor.org_unit WHERE id = item_object.circ_lib;
        END IF;

        PERFORM * FROM actor.org_unit_descendants( transit_source.id, transit_range_ou_type.depth ) WHERE id = v_pickup_ou;

        IF NOT FOUND THEN
            result.fail_part := 'transit_range';
            result.success := FALSE;
            done := TRUE;
            RETURN NEXT result;
        END IF;
    END IF;
 
    -- Proximity of user's home_ou to the pickup_lib to see if penalty should be ignored.
    SELECT INTO pickup_prox prox FROM actor.org_unit_proximity WHERE from_org = user_object.home_ou AND to_org = v_pickup_ou;
    -- Proximity of user's home_ou to the items' lib to see if penalty should be ignored.
    IF hold_test.distance_is_from_owner THEN
        SELECT INTO item_prox prox FROM actor.org_unit_proximity WHERE from_org = user_object.home_ou AND to_org = item_cn_object.owning_lib;
    ELSE
        SELECT INTO item_prox prox FROM actor.org_unit_proximity WHERE from_org = user_object.home_ou AND to_org = item_object.circ_lib;
    END IF;

    FOR standing_penalty IN
        SELECT  DISTINCT csp.*
          FROM  actor.usr_standing_penalty usp
                JOIN config.standing_penalty csp ON (csp.id = usp.standing_penalty)
          WHERE usr = match_user
                AND usp.org_unit IN ( SELECT * FROM unnest(context_org_list) )
                AND (usp.stop_date IS NULL or usp.stop_date > NOW())
                AND (csp.ignore_proximity IS NULL OR csp.ignore_proximity < item_prox
                     OR csp.ignore_proximity < pickup_prox)
                AND csp.block_list LIKE '%' || hold_penalty || '%' LOOP

        result.fail_part := standing_penalty.name;
        result.success := FALSE;
        done := TRUE;
        RETURN NEXT result;
    END LOOP;

    IF hold_test.stop_blocked_user IS TRUE THEN
        FOR standing_penalty IN
            SELECT  DISTINCT csp.*
              FROM  actor.usr_standing_penalty usp
                    JOIN config.standing_penalty csp ON (csp.id = usp.standing_penalty)
              WHERE usr = match_user
                    AND usp.org_unit IN ( SELECT * FROM unnest(context_org_list) )
                    AND (usp.stop_date IS NULL or usp.stop_date > NOW())
                    AND csp.block_list LIKE '%CIRC%' LOOP
    
            result.fail_part := standing_penalty.name;
            result.success := FALSE;
            done := TRUE;
            RETURN NEXT result;
        END LOOP;
    END IF;

    IF hold_test.max_holds IS NOT NULL AND NOT retargetting THEN
        SELECT    INTO hold_count COUNT(*)
          FROM    action.hold_request
          WHERE    usr = match_user
            AND fulfillment_time IS NULL
            AND cancel_time IS NULL
            AND CASE WHEN hold_test.include_frozen_holds THEN TRUE ELSE frozen IS FALSE END;

        IF hold_count >= hold_test.max_holds THEN
            result.fail_part := 'config.hold_matrix_test.max_holds';
            result.success := FALSE;
            done := TRUE;
            RETURN NEXT result;
        END IF;
    END IF;

    IF item_object.age_protect IS NOT NULL THEN
        SELECT INTO age_protect_object * FROM config.rule_age_hold_protect WHERE id = item_object.age_protect;
        IF hold_test.distance_is_from_owner THEN
            SELECT INTO use_active_date value FROM actor.org_unit_ancestor_setting('circ.holds.age_protect.active_date', item_cn_object.owning_lib);
        ELSE
            SELECT INTO use_active_date value FROM actor.org_unit_ancestor_setting('circ.holds.age_protect.active_date', item_object.circ_lib);
        END IF;
        IF use_active_date = 'true' THEN
            age_protect_date := COALESCE(item_object.active_date, NOW());
        ELSE
            age_protect_date := item_object.create_date;
        END IF;
        IF age_protect_date + age_protect_object.age > NOW() THEN
            IF hold_test.distance_is_from_owner THEN
                SELECT INTO item_cn_object * FROM asset.call_number WHERE id = item_object.call_number;
                SELECT INTO hold_transit_prox prox FROM actor.org_unit_proximity WHERE from_org = item_cn_object.owning_lib AND to_org = v_pickup_ou;
            ELSE
                SELECT INTO hold_transit_prox prox FROM actor.org_unit_proximity WHERE from_org = item_object.circ_lib AND to_org = v_pickup_ou;
            END IF;

            IF hold_transit_prox > age_protect_object.prox THEN
                result.fail_part := 'config.rule_age_hold_protect.prox';
                result.success := FALSE;
                done := TRUE;
                RETURN NEXT result;
            END IF;
        END IF;
    END IF;

    IF NOT done THEN
        RETURN NEXT result;
    END IF;

    RETURN;
END;
$func$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION action.item_user_circ_test( circ_ou INT, match_item BIGINT, match_user INT, renewal BOOL ) RETURNS SETOF action.circ_matrix_test_result AS $func$
DECLARE
    user_object             actor.usr%ROWTYPE;
    standing_penalty        config.standing_penalty%ROWTYPE;
    item_object             asset.copy%ROWTYPE;
    item_status_object      config.copy_status%ROWTYPE;
    item_location_object    asset.copy_location%ROWTYPE;
    result                  action.circ_matrix_test_result;
    circ_test               action.found_circ_matrix_matchpoint;
    circ_matchpoint         config.circ_matrix_matchpoint%ROWTYPE;
    circ_limit_set          config.circ_limit_set%ROWTYPE;
    hold_ratio              action.hold_stats%ROWTYPE;
    penalty_type            TEXT;
    items_out               INT;
    context_org_list        INT[];
    done                    BOOL := FALSE;
    item_prox               INT;
    home_prox               INT;
BEGIN
    -- Assume success unless we hit a failure condition
    result.success := TRUE;

    -- Need user info to look up matchpoints
    SELECT INTO user_object * FROM actor.usr WHERE id = match_user AND NOT deleted;

    -- (Insta)Fail if we couldn't find the user
    IF user_object.id IS NULL THEN
        result.fail_part := 'no_user';
        result.success := FALSE;
        done := TRUE;
        RETURN NEXT result;
        RETURN;
    END IF;

    -- Need item info to look up matchpoints
    SELECT INTO item_object * FROM asset.copy WHERE id = match_item AND NOT deleted;

    -- (Insta)Fail if we couldn't find the item 
    IF item_object.id IS NULL THEN
        result.fail_part := 'no_item';
        result.success := FALSE;
        done := TRUE;
        RETURN NEXT result;
        RETURN;
    END IF;

    SELECT INTO circ_test * FROM action.find_circ_matrix_matchpoint(circ_ou, item_object, user_object, renewal);

    circ_matchpoint             := circ_test.matchpoint;
    result.matchpoint           := circ_matchpoint.id;
    result.circulate            := circ_matchpoint.circulate;
    result.duration_rule        := circ_matchpoint.duration_rule;
    result.recurring_fine_rule  := circ_matchpoint.recurring_fine_rule;
    result.max_fine_rule        := circ_matchpoint.max_fine_rule;
    result.hard_due_date        := circ_matchpoint.hard_due_date;
    result.renewals             := circ_matchpoint.renewals;
    result.grace_period         := circ_matchpoint.grace_period;
    result.buildrows            := circ_test.buildrows;

    -- (Insta)Fail if we couldn't find a matchpoint
    IF circ_test.success = false THEN
        result.fail_part := 'no_matchpoint';
        result.success := FALSE;
        done := TRUE;
        RETURN NEXT result;
        RETURN;
    END IF;

    -- All failures before this point are non-recoverable
    -- Below this point are possibly overridable failures

    -- Fail if the user is barred
    IF user_object.barred IS TRUE THEN
        result.fail_part := 'actor.usr.barred';
        result.success := FALSE;
        done := TRUE;
        RETURN NEXT result;
    END IF;

    -- Fail if the item can't circulate
    IF item_object.circulate IS FALSE THEN
        result.fail_part := 'asset.copy.circulate';
        result.success := FALSE;
        done := TRUE;
        RETURN NEXT result;
    END IF;

    -- Fail if the item isn't in a circulateable status on a non-renewal
    IF NOT renewal AND item_object.status NOT IN ( 0, 7, 8 ) THEN 
        result.fail_part := 'asset.copy.status';
        result.success := FALSE;
        done := TRUE;
        RETURN NEXT result;
    -- Alternately, fail if the item isn't checked out on a renewal
    ELSIF renewal AND item_object.status <> 1 THEN
        result.fail_part := 'asset.copy.status';
        result.success := FALSE;
        done := TRUE;
        RETURN NEXT result;
    END IF;

    -- Fail if the item can't circulate because of the shelving location
    SELECT INTO item_location_object * FROM asset.copy_location WHERE id = item_object.location;
    IF item_location_object.circulate IS FALSE THEN
        result.fail_part := 'asset.copy_location.circulate';
        result.success := FALSE;
        done := TRUE;
        RETURN NEXT result;
    END IF;

    -- Use Circ OU for penalties and such
    SELECT INTO context_org_list ARRAY_AGG(id) FROM actor.org_unit_full_path( circ_ou );

    -- Proximity of user's home_ou to circ_ou to see if penalties should be ignored.
    SELECT INTO home_prox prox FROM actor.org_unit_proximity WHERE from_org = user_object.home_ou AND to_org = circ_ou;

    -- Proximity of user's home_ou to item circ_lib to see if penalties should be ignored.
    SELECT INTO item_prox prox FROM actor.org_unit_proximity WHERE from_org = user_object.home_ou AND to_org = item_object.circ_lib;

    IF renewal THEN
        penalty_type = '%RENEW%';
    ELSE
        penalty_type = '%CIRC%';
    END IF;

    FOR standing_penalty IN
        SELECT  DISTINCT csp.*
          FROM  actor.usr_standing_penalty usp
                JOIN config.standing_penalty csp ON (csp.id = usp.standing_penalty)
          WHERE usr = match_user
                AND usp.org_unit IN ( SELECT * FROM unnest(context_org_list) )
                AND (usp.stop_date IS NULL or usp.stop_date > NOW())
                AND (csp.ignore_proximity IS NULL
                     OR csp.ignore_proximity < home_prox
                     OR csp.ignore_proximity < item_prox)
                AND csp.block_list LIKE penalty_type LOOP

        result.fail_part := standing_penalty.name;
        result.success := FALSE;
        done := TRUE;
        RETURN NEXT result;
    END LOOP;

    -- Fail if the test is set to hard non-circulating
    IF circ_matchpoint.circulate IS FALSE THEN
        result.fail_part := 'config.circ_matrix_test.circulate';
        result.success := FALSE;
        done := TRUE;
        RETURN NEXT result;
    END IF;

    -- Fail if the total copy-hold ratio is too low
    IF circ_matchpoint.total_copy_hold_ratio IS NOT NULL THEN
        SELECT INTO hold_ratio * FROM action.copy_related_hold_stats(match_item);
        IF hold_ratio.total_copy_ratio IS NOT NULL AND hold_ratio.total_copy_ratio < circ_matchpoint.total_copy_hold_ratio THEN
            result.fail_part := 'config.circ_matrix_test.total_copy_hold_ratio';
            result.success := FALSE;
            done := TRUE;
            RETURN NEXT result;
        END IF;
    END IF;

    -- Fail if the available copy-hold ratio is too low
    IF circ_matchpoint.available_copy_hold_ratio IS NOT NULL THEN
        IF hold_ratio.hold_count IS NULL THEN
            SELECT INTO hold_ratio * FROM action.copy_related_hold_stats(match_item);
        END IF;
        IF hold_ratio.available_copy_ratio IS NOT NULL AND hold_ratio.available_copy_ratio < circ_matchpoint.available_copy_hold_ratio THEN
            result.fail_part := 'config.circ_matrix_test.available_copy_hold_ratio';
            result.success := FALSE;
            done := TRUE;
            RETURN NEXT result;
        END IF;
    END IF;

    -- Fail if the user has too many items out by defined limit sets
    FOR circ_limit_set IN SELECT ccls.* FROM config.circ_limit_set ccls
      JOIN config.circ_matrix_limit_set_map ccmlsm ON ccmlsm.limit_set = ccls.id
      WHERE ccmlsm.active AND ( ccmlsm.matchpoint = circ_matchpoint.id OR
        ( ccmlsm.matchpoint IN (SELECT * FROM unnest(result.buildrows)) AND ccmlsm.fallthrough )
        ) LOOP
            IF circ_limit_set.items_out > 0 AND NOT renewal THEN
                SELECT INTO context_org_list ARRAY_AGG(aou.id)
                  FROM actor.org_unit_full_path( circ_ou ) aou
                    JOIN actor.org_unit_type aout ON aou.ou_type = aout.id
                  WHERE aout.depth >= circ_limit_set.depth;
                IF circ_limit_set.global THEN
                    WITH RECURSIVE descendant_depth AS (
                        SELECT  ou.id,
                            ou.parent_ou
                        FROM  actor.org_unit ou
                        WHERE ou.id IN (SELECT * FROM unnest(context_org_list))
                            UNION
                        SELECT  ou.id,
                            ou.parent_ou
                        FROM  actor.org_unit ou
                            JOIN descendant_depth ot ON (ot.id = ou.parent_ou)
                    ) SELECT INTO context_org_list ARRAY_AGG(ou.id) FROM actor.org_unit ou JOIN descendant_depth USING (id);
                END IF;
                SELECT INTO items_out COUNT(DISTINCT circ.id)
                  FROM action.circulation circ
                    JOIN asset.copy copy ON (copy.id = circ.target_copy)
                    LEFT JOIN action.circulation_limit_group_map aclgm ON (circ.id = aclgm.circ)
                  WHERE circ.usr = match_user
                    AND circ.circ_lib IN (SELECT * FROM unnest(context_org_list))
                    AND circ.checkin_time IS NULL
                    AND (circ.stop_fines IN ('MAXFINES','LONGOVERDUE') OR circ.stop_fines IS NULL)
                    AND (copy.circ_modifier IN (SELECT circ_mod FROM config.circ_limit_set_circ_mod_map WHERE limit_set = circ_limit_set.id)
                        OR copy.location IN (SELECT copy_loc FROM config.circ_limit_set_copy_loc_map WHERE limit_set = circ_limit_set.id)
                        OR aclgm.limit_group IN (SELECT limit_group FROM config.circ_limit_set_group_map WHERE limit_set = circ_limit_set.id)
                    );
                IF items_out >= circ_limit_set.items_out THEN
                    result.fail_part := 'config.circ_matrix_circ_mod_test';
                    result.success := FALSE;
                    done := TRUE;
                    RETURN NEXT result;
                END IF;
            END IF;
            SELECT INTO result.limit_groups result.limit_groups || ARRAY_AGG(limit_group) FROM config.circ_limit_set_group_map WHERE limit_set = circ_limit_set.id AND NOT check_only;
    END LOOP;

    -- If we passed everything, return the successful matchpoint
    IF NOT done THEN
        RETURN NEXT result;
    END IF;

    RETURN;
END;
$func$ LANGUAGE plpgsql;

SELECT evergreen.upgrade_deps_block_check('0952', :eg_version); --miker/kmlussier/gmcharlt

INSERT INTO config.metabib_field ( id, field_class, name, label, format, xpath, browse_field, facet_field, facet_xpath, joiner ) VALUES
    (33, 'identifier', 'genre', oils_i18n_gettext(33, 'Genre', 'cmf', 'label'), 'marcxml', $$//marc:datafield[@tag='655']$$, FALSE, TRUE, $$//*[local-name()='subfield' and contains('abvxyz',@code)]$$, ' -- ' ); -- /* to fool vim */;

INSERT INTO config.metabib_field_index_norm_map (field,norm)
    SELECT  m.id,
            i.id
      FROM  config.metabib_field m,
        config.index_normalizer i
      WHERE i.func IN ('search_normalize','split_date_range')
            AND m.id IN (33);

SELECT evergreen.upgrade_deps_block_check('0953', :eg_version);

CREATE OR REPLACE FUNCTION unapi.bre (
    obj_id BIGINT,
    format TEXT,
    ename TEXT,
    includes TEXT[],
    org TEXT,
    depth INT DEFAULT NULL,
    slimit HSTORE DEFAULT NULL,
    soffset HSTORE DEFAULT NULL,
    include_xmlns BOOL DEFAULT TRUE,
    pref_lib INT DEFAULT NULL
)
RETURNS XML AS $F$
DECLARE
    me      biblio.record_entry%ROWTYPE;
    layout  unapi.bre_output_layout%ROWTYPE;
    xfrm    config.xml_transform%ROWTYPE;
    ouid    INT;
    tmp_xml TEXT;
    top_el  TEXT;
    output  XML;
    hxml    XML;
    axml    XML;
    source  XML;
BEGIN

    IF org = '-' OR org IS NULL THEN
        SELECT shortname INTO org FROM evergreen.org_top();
    END IF;

    SELECT id INTO ouid FROM actor.org_unit WHERE shortname = org;

    IF ouid IS NULL THEN
        RETURN NULL::XML;
    END IF;

    IF format = 'holdings_xml' THEN -- the special case
        output := unapi.holdings_xml( obj_id, ouid, org, depth, includes, slimit, soffset, include_xmlns);
        RETURN output;
    END IF;

    SELECT * INTO layout FROM unapi.bre_output_layout WHERE name = format;

    IF layout.name IS NULL THEN
        RETURN NULL::XML;
    END IF;

    SELECT * INTO xfrm FROM config.xml_transform WHERE name = layout.transform;

    SELECT * INTO me FROM biblio.record_entry WHERE id = obj_id;

    -- grab bib_source, if any
    IF ('cbs' = ANY (includes) AND me.source IS NOT NULL) THEN
        source := unapi.cbs(me.source,NULL,NULL,NULL,NULL);
    ELSE
        source := NULL::XML;
    END IF;

    -- grab SVF if we need them
    IF ('mra' = ANY (includes)) THEN 
        axml := unapi.mra(obj_id,NULL,NULL,NULL,NULL);
    ELSE
        axml := NULL::XML;
    END IF;

    -- grab holdings if we need them
    IF ('holdings_xml' = ANY (includes)) THEN 
        hxml := unapi.holdings_xml(obj_id, ouid, org, depth, evergreen.array_remove_item_by_value(includes,'holdings_xml'), slimit, soffset, include_xmlns, pref_lib);
    ELSE
        hxml := NULL::XML;
    END IF;


    -- generate our item node


    IF format = 'marcxml' THEN
        tmp_xml := me.marc;
        IF tmp_xml !~ E'<marc:' THEN -- If we're not using the prefixed namespace in this record, then remove all declarations of it
           tmp_xml := REGEXP_REPLACE(tmp_xml, ' xmlns:marc="http://www.loc.gov/MARC21/slim"', '', 'g');
        END IF; 
    ELSE
        tmp_xml := oils_xslt_process(me.marc, xfrm.xslt)::XML;
    END IF;

    top_el := REGEXP_REPLACE(tmp_xml, E'^.*?<((?:\\S+:)?' || layout.holdings_element || ').*$', E'\\1');

    IF source IS NOT NULL THEN
        tmp_xml := REGEXP_REPLACE(tmp_xml, '</' || top_el || '>(.*?)$', source || '</' || top_el || E'>\\1');
    END IF;

    IF axml IS NOT NULL THEN 
        tmp_xml := REGEXP_REPLACE(tmp_xml, '</' || top_el || '>(.*?)$', axml || '</' || top_el || E'>\\1');
    END IF;

    IF hxml IS NOT NULL THEN -- XXX how do we configure the holdings position?
        tmp_xml := REGEXP_REPLACE(tmp_xml, '</' || top_el || '>(.*?)$', hxml || '</' || top_el || E'>\\1');
    END IF;

    IF ('bre.unapi' = ANY (includes)) THEN 
        output := REGEXP_REPLACE(
            tmp_xml,
            '</' || top_el || '>(.*?)',
            XMLELEMENT(
                name abbr,
                XMLATTRIBUTES(
                    'http://www.w3.org/1999/xhtml' AS xmlns,
                    'unapi-id' AS class,
                    'tag:open-ils.org:U2@bre/' || obj_id || '/' || org AS title
                )
            )::TEXT || '</' || top_el || E'>\\1'
        );
    ELSE
        output := tmp_xml;
    END IF;

    IF ('bre.extern' = ANY (includes)) THEN 
        output := REGEXP_REPLACE(
            tmp_xml,
            '</' || top_el || '>(.*?)',
            XMLELEMENT(
                name extern,
                XMLATTRIBUTES(
                    'http://open-ils.org/spec/biblio/v1' AS xmlns,
                    me.creator AS creator,
                    me.editor AS editor,
                    me.create_date AS create_date,
                    me.edit_date AS edit_date,
                    me.quality AS quality,
                    me.fingerprint AS fingerprint,
                    me.tcn_source AS tcn_source,
                    me.tcn_value AS tcn_value,
                    me.owner AS owner,
                    me.share_depth AS share_depth,
                    me.active AS active,
                    me.deleted AS deleted
                )
            )::TEXT || '</' || top_el || E'>\\1'
        );
    ELSE
        output := tmp_xml;
    END IF;

    output := REGEXP_REPLACE(output::TEXT,E'>\\s+<','><','gs')::XML;
    RETURN output;
END;
$F$ LANGUAGE PLPGSQL STABLE;

SELECT evergreen.upgrade_deps_block_check('0954', :eg_version);

ALTER TABLE acq.fund_debit 
    ADD COLUMN invoice_entry INTEGER 
        REFERENCES acq.invoice_entry (id)
        ON DELETE SET NULL;

CREATE INDEX fund_debit_invoice_entry_idx ON acq.fund_debit (invoice_entry);
CREATE INDEX lineitem_detail_fund_debit_idx ON acq.lineitem_detail (fund_debit);

SELECT evergreen.upgrade_deps_block_check('0955', :eg_version);

UPDATE config.org_unit_setting_type
SET description = 'Regular expression defining the password format.  Note: Be sure to update the update_password_msg.tt2 TPAC template with a user-friendly description of your password strength requirements.'
WHERE NAME = 'global.password_regex';

SELECT evergreen.upgrade_deps_block_check('0956', :eg_version);

ALTER TABLE money.credit_card_payment 
    DROP COLUMN cc_type,
    DROP COLUMN expire_month,
    DROP COLUMN expire_year,
    DROP COLUMN cc_first_name,
    DROP COLUMN cc_last_name;

SELECT evergreen.upgrade_deps_block_check('0957', :eg_version);

-- Remove references to dropped CC payment columns in the print/email 
-- payment receipt templates, but only if the in-db template matches 
-- the stock template.
-- The actual diff here is only about 8 lines.

UPDATE action_trigger.event_definition SET template = 
$$
[%- USE date -%]
[%- SET user = target.0.xact.usr -%]
To: [%- params.recipient_email || user.email %]
From: [%- params.sender_email || default_sender %]
Subject: Payment Receipt

[% date.format -%]
[%- SET xact_mp_hash = {} -%]
[%- FOR mp IN target %][%# Template is hooked around payments, but let us make the receipt focused on transactions -%]
    [%- SET xact_id = mp.xact.id -%]
    [%- IF ! xact_mp_hash.defined( xact_id ) -%][%- xact_mp_hash.$xact_id = { 'xact' => mp.xact, 'payments' => [] } -%][%- END -%]
    [%- xact_mp_hash.$xact_id.payments.push(mp) -%]
[%- END -%]
[%- FOR xact_id IN xact_mp_hash.keys.sort -%]
    [%- SET xact = xact_mp_hash.$xact_id.xact %]
Transaction ID: [% xact_id %]
    [% IF xact.circulation %][% helpers.get_copy_bib_basics(xact.circulation.target_copy).title %]
    [% ELSE %]Miscellaneous
    [% END %]
    Line item billings:
        [%- SET mb_type_hash = {} -%]
        [%- FOR mb IN xact.billings %][%# Group billings by their btype -%]
            [%- IF mb.voided == 'f' -%]
                [%- SET mb_type = mb.btype.id -%]
                [%- IF ! mb_type_hash.defined( mb_type ) -%][%- mb_type_hash.$mb_type = { 'sum' => 0.00, 'billings' => [] } -%][%- END -%]
                [%- IF ! mb_type_hash.$mb_type.defined( 'first_ts' ) -%][%- mb_type_hash.$mb_type.first_ts = mb.billing_ts -%][%- END -%]
                [%- mb_type_hash.$mb_type.last_ts = mb.billing_ts -%]
                [%- mb_type_hash.$mb_type.sum = mb_type_hash.$mb_type.sum + mb.amount -%]
                [%- mb_type_hash.$mb_type.billings.push( mb ) -%]
            [%- END -%]
        [%- END -%]
        [%- FOR mb_type IN mb_type_hash.keys.sort -%]
            [%- IF mb_type == 1 %][%-# Consolidated view of overdue billings -%]
                $[% mb_type_hash.$mb_type.sum %] for [% mb_type_hash.$mb_type.billings.0.btype.name %] 
                    on [% mb_type_hash.$mb_type.first_ts %] through [% mb_type_hash.$mb_type.last_ts %]
            [%- ELSE -%][%# all other billings show individually %]
                [% FOR mb IN mb_type_hash.$mb_type.billings %]
                    $[% mb.amount %] for [% mb.btype.name %] on [% mb.billing_ts %] [% mb.note %]
                [% END %]
            [% END %]
        [% END %]
    Line item payments:
        [% FOR mp IN xact_mp_hash.$xact_id.payments %]
            Payment ID: [% mp.id %]
                Paid [% mp.amount %] via [% SWITCH mp.payment_type -%]
                    [% CASE "cash_payment" %]cash
                    [% CASE "check_payment" %]check
                    [% CASE "credit_card_payment" %]credit card
                    [%- IF mp.credit_card_payment.cc_number %] ([% mp.credit_card_payment.cc_number %])[% END %]
                    [% CASE "credit_payment" %]credit
                    [% CASE "forgive_payment" %]forgiveness
                    [% CASE "goods_payment" %]goods
                    [% CASE "work_payment" %]work
                [%- END %] on [% mp.payment_ts %] [% mp.note %]
        [% END %]
[% END %]
$$

WHERE id = 29 AND template =

$$
[%- USE date -%]
[%- SET user = target.0.xact.usr -%]
To: [%- params.recipient_email || user.email %]
From: [%- params.sender_email || default_sender %]
Subject: Payment Receipt

[% date.format -%]
[%- SET xact_mp_hash = {} -%]
[%- FOR mp IN target %][%# Template is hooked around payments, but let us make the receipt focused on transactions -%]
    [%- SET xact_id = mp.xact.id -%]
    [%- IF ! xact_mp_hash.defined( xact_id ) -%][%- xact_mp_hash.$xact_id = { 'xact' => mp.xact, 'payments' => [] } -%][%- END -%]
    [%- xact_mp_hash.$xact_id.payments.push(mp) -%]
[%- END -%]
[%- FOR xact_id IN xact_mp_hash.keys.sort -%]
    [%- SET xact = xact_mp_hash.$xact_id.xact %]
Transaction ID: [% xact_id %]
    [% IF xact.circulation %][% helpers.get_copy_bib_basics(xact.circulation.target_copy).title %]
    [% ELSE %]Miscellaneous
    [% END %]
    Line item billings:
        [%- SET mb_type_hash = {} -%]
        [%- FOR mb IN xact.billings %][%# Group billings by their btype -%]
            [%- IF mb.voided == 'f' -%]
                [%- SET mb_type = mb.btype.id -%]
                [%- IF ! mb_type_hash.defined( mb_type ) -%][%- mb_type_hash.$mb_type = { 'sum' => 0.00, 'billings' => [] } -%][%- END -%]
                [%- IF ! mb_type_hash.$mb_type.defined( 'first_ts' ) -%][%- mb_type_hash.$mb_type.first_ts = mb.billing_ts -%][%- END -%]
                [%- mb_type_hash.$mb_type.last_ts = mb.billing_ts -%]
                [%- mb_type_hash.$mb_type.sum = mb_type_hash.$mb_type.sum + mb.amount -%]
                [%- mb_type_hash.$mb_type.billings.push( mb ) -%]
            [%- END -%]
        [%- END -%]
        [%- FOR mb_type IN mb_type_hash.keys.sort -%]
            [%- IF mb_type == 1 %][%-# Consolidated view of overdue billings -%]
                $[% mb_type_hash.$mb_type.sum %] for [% mb_type_hash.$mb_type.billings.0.btype.name %] 
                    on [% mb_type_hash.$mb_type.first_ts %] through [% mb_type_hash.$mb_type.last_ts %]
            [%- ELSE -%][%# all other billings show individually %]
                [% FOR mb IN mb_type_hash.$mb_type.billings %]
                    $[% mb.amount %] for [% mb.btype.name %] on [% mb.billing_ts %] [% mb.note %]
                [% END %]
            [% END %]
        [% END %]
    Line item payments:
        [% FOR mp IN xact_mp_hash.$xact_id.payments %]
            Payment ID: [% mp.id %]
                Paid [% mp.amount %] via [% SWITCH mp.payment_type -%]
                    [% CASE "cash_payment" %]cash
                    [% CASE "check_payment" %]check
                    [% CASE "credit_card_payment" %]credit card (
                        [%- SET cc_chunks = mp.credit_card_payment.cc_number.replace(' ','').chunk(4); -%]
                        [%- cc_chunks.slice(0, -1+cc_chunks.max).join.replace('\S','X') -%] 
                        [% cc_chunks.last -%]
                        exp [% mp.credit_card_payment.expire_month %]/[% mp.credit_card_payment.expire_year -%]
                    )
                    [% CASE "credit_payment" %]credit
                    [% CASE "forgive_payment" %]forgiveness
                    [% CASE "goods_payment" %]goods
                    [% CASE "work_payment" %]work
                [%- END %] on [% mp.payment_ts %] [% mp.note %]
        [% END %]
[% END %]
$$;


UPDATE action_trigger.event_definition SET template = 
$$
[%- USE date -%][%- SET user = target.0.xact.usr -%]
<div style="li { padding: 8px; margin 5px; }">
    <div>[% date.format %]</div><br/>
    <ol>
    [% SET xact_mp_hash = {} %]
    [% FOR mp IN target %][%# Template is hooked around payments, but let us make the receipt focused on transactions %]
        [% SET xact_id = mp.xact.id %]
        [% IF ! xact_mp_hash.defined( xact_id ) %][% xact_mp_hash.$xact_id = { 'xact' => mp.xact, 'payments' => [] } %][% END %]
        [% xact_mp_hash.$xact_id.payments.push(mp) %]
    [% END %]
    [% FOR xact_id IN xact_mp_hash.keys.sort %]
        [% SET xact = xact_mp_hash.$xact_id.xact %]
        <li>Transaction ID: [% xact_id %]
            [% IF xact.circulation %][% helpers.get_copy_bib_basics(xact.circulation.target_copy).title %]
            [% ELSE %]Miscellaneous
            [% END %]
            Line item billings:<ol>
                [% SET mb_type_hash = {} %]
                [% FOR mb IN xact.billings %][%# Group billings by their btype %]
                    [% IF mb.voided == 'f' %]
                        [% SET mb_type = mb.btype.id %]
                        [% IF ! mb_type_hash.defined( mb_type ) %][% mb_type_hash.$mb_type = { 'sum' => 0.00, 'billings' => [] } %][% END %]
                        [% IF ! mb_type_hash.$mb_type.defined( 'first_ts' ) %][% mb_type_hash.$mb_type.first_ts = mb.billing_ts %][% END %]
                        [% mb_type_hash.$mb_type.last_ts = mb.billing_ts %]
                        [% mb_type_hash.$mb_type.sum = mb_type_hash.$mb_type.sum + mb.amount %]
                        [% mb_type_hash.$mb_type.billings.push( mb ) %]
                    [% END %]
                [% END %]
                [% FOR mb_type IN mb_type_hash.keys.sort %]
                    <li>[% IF mb_type == 1 %][%# Consolidated view of overdue billings %]
                        $[% mb_type_hash.$mb_type.sum %] for [% mb_type_hash.$mb_type.billings.0.btype.name %] 
                            on [% mb_type_hash.$mb_type.first_ts %] through [% mb_type_hash.$mb_type.last_ts %]
                    [% ELSE %][%# all other billings show individually %]
                        [% FOR mb IN mb_type_hash.$mb_type.billings %]
                            $[% mb.amount %] for [% mb.btype.name %] on [% mb.billing_ts %] [% mb.note %]
                        [% END %]
                    [% END %]</li>
                [% END %]
            </ol>
            Line item payments:<ol>
                [% FOR mp IN xact_mp_hash.$xact_id.payments %]
                    <li>Payment ID: [% mp.id %]
                        Paid [% mp.amount %] via [% SWITCH mp.payment_type -%]
                            [% CASE "cash_payment" %]cash
                            [% CASE "check_payment" %]check
                            [% CASE "credit_card_payment" %]credit card
                            [%- IF mp.credit_card_payment.cc_number %] ([% mp.credit_card_payment.cc_number %])[% END %]
                            [% CASE "credit_payment" %]credit
                            [% CASE "forgive_payment" %]forgiveness
                            [% CASE "goods_payment" %]goods
                            [% CASE "work_payment" %]work
                        [%- END %] on [% mp.payment_ts %] [% mp.note %]
                    </li>
                [% END %]
            </ol>
        </li>
    [% END %]
    </ol>
</div>
$$

WHERE id = 30 AND template =

$$
[%- USE date -%][%- SET user = target.0.xact.usr -%]
<div style="li { padding: 8px; margin 5px; }">
    <div>[% date.format %]</div><br/>
    <ol>
    [% SET xact_mp_hash = {} %]
    [% FOR mp IN target %][%# Template is hooked around payments, but let us make the receipt focused on transactions %]
        [% SET xact_id = mp.xact.id %]
        [% IF ! xact_mp_hash.defined( xact_id ) %][% xact_mp_hash.$xact_id = { 'xact' => mp.xact, 'payments' => [] } %][% END %]
        [% xact_mp_hash.$xact_id.payments.push(mp) %]
    [% END %]
    [% FOR xact_id IN xact_mp_hash.keys.sort %]
        [% SET xact = xact_mp_hash.$xact_id.xact %]
        <li>Transaction ID: [% xact_id %]
            [% IF xact.circulation %][% helpers.get_copy_bib_basics(xact.circulation.target_copy).title %]
            [% ELSE %]Miscellaneous
            [% END %]
            Line item billings:<ol>
                [% SET mb_type_hash = {} %]
                [% FOR mb IN xact.billings %][%# Group billings by their btype %]
                    [% IF mb.voided == 'f' %]
                        [% SET mb_type = mb.btype.id %]
                        [% IF ! mb_type_hash.defined( mb_type ) %][% mb_type_hash.$mb_type = { 'sum' => 0.00, 'billings' => [] } %][% END %]
                        [% IF ! mb_type_hash.$mb_type.defined( 'first_ts' ) %][% mb_type_hash.$mb_type.first_ts = mb.billing_ts %][% END %]
                        [% mb_type_hash.$mb_type.last_ts = mb.billing_ts %]
                        [% mb_type_hash.$mb_type.sum = mb_type_hash.$mb_type.sum + mb.amount %]
                        [% mb_type_hash.$mb_type.billings.push( mb ) %]
                    [% END %]
                [% END %]
                [% FOR mb_type IN mb_type_hash.keys.sort %]
                    <li>[% IF mb_type == 1 %][%# Consolidated view of overdue billings %]
                        $[% mb_type_hash.$mb_type.sum %] for [% mb_type_hash.$mb_type.billings.0.btype.name %] 
                            on [% mb_type_hash.$mb_type.first_ts %] through [% mb_type_hash.$mb_type.last_ts %]
                    [% ELSE %][%# all other billings show individually %]
                        [% FOR mb IN mb_type_hash.$mb_type.billings %]
                            $[% mb.amount %] for [% mb.btype.name %] on [% mb.billing_ts %] [% mb.note %]
                        [% END %]
                    [% END %]</li>
                [% END %]
            </ol>
            Line item payments:<ol>
                [% FOR mp IN xact_mp_hash.$xact_id.payments %]
                    <li>Payment ID: [% mp.id %]
                        Paid [% mp.amount %] via [% SWITCH mp.payment_type -%]
                            [% CASE "cash_payment" %]cash
                            [% CASE "check_payment" %]check
                            [% CASE "credit_card_payment" %]credit card (
                                [%- SET cc_chunks = mp.credit_card_payment.cc_number.replace(' ','').chunk(4); -%]
                                [%- cc_chunks.slice(0, -1+cc_chunks.max).join.replace('\S','X') -%] 
                                [% cc_chunks.last -%]
                                exp [% mp.credit_card_payment.expire_month %]/[% mp.credit_card_payment.expire_year -%]
                            )
                            [% CASE "credit_payment" %]credit
                            [% CASE "forgive_payment" %]forgiveness
                            [% CASE "goods_payment" %]goods
                            [% CASE "work_payment" %]work
                        [%- END %] on [% mp.payment_ts %] [% mp.note %]
                    </li>
                [% END %]
            </ol>
        </li>
    [% END %]
    </ol>
</div>
$$;


SELECT evergreen.upgrade_deps_block_check('0958', :eg_version);

CREATE OR REPLACE FUNCTION search.facets_for_record_set(ignore_facet_classes TEXT[], hits BIGINT[]) RETURNS TABLE (id INT, value TEXT, count BIGINT) AS $$
    SELECT id, value, count FROM (
        SELECT mfae.field AS id,
               mfae.value,
               COUNT(DISTINCT mmrsm.source),
               row_number() OVER (
                PARTITION BY mfae.field ORDER BY COUNT(distinct mmrsm.source) DESC
               ) AS rownum
        FROM metabib.facet_entry mfae
        JOIN metabib.metarecord_source_map mmrsm ON (mfae.source = mmrsm.source)
        JOIN config.metabib_field cmf ON (cmf.id = mfae.field)
        WHERE mmrsm.source IN (SELECT * FROM unnest($2))
        AND cmf.facet_field
        AND cmf.field_class NOT IN (SELECT * FROM unnest($1))
        GROUP by 1, 2
    ) all_facets
    WHERE rownum <= (SELECT COALESCE((SELECT value::INT FROM config.global_flag WHERE name = 'search.max_facets_per_field' AND enabled), 1000));
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION search.facets_for_metarecord_set(ignore_facet_classes TEXT[], hits BIGINT[]) RETURNS TABLE (id INT, value TEXT, count BIGINT) AS $$
    SELECT id, value, count FROM (
        SELECT mfae.field AS id,
               mfae.value,
               COUNT(DISTINCT mmrsm.metarecord),
               row_number() OVER (
                PARTITION BY mfae.field ORDER BY COUNT(distinct mmrsm.metarecord) DESC
               ) AS rownum
        FROM metabib.facet_entry mfae
        JOIN metabib.metarecord_source_map mmrsm ON (mfae.source = mmrsm.source)
        JOIN config.metabib_field cmf ON (cmf.id = mfae.field)
        WHERE mmrsm.metarecord IN (SELECT * FROM unnest($2))
        AND cmf.facet_field
        AND cmf.field_class NOT IN (SELECT * FROM unnest($1))
        GROUP by 1, 2
    ) all_facets
    WHERE rownum <= (SELECT COALESCE((SELECT value::INT FROM config.global_flag WHERE name = 'search.max_facets_per_field' AND enabled), 1000));
$$ LANGUAGE SQL;

INSERT INTO config.global_flag (name, value, label, enabled)
    VALUES (
        'search.max_facets_per_field',
        '1000',
        oils_i18n_gettext(
            'search.max_facets_per_field',
            'Search: maximum number of facet values to retrieve for each facet field',
            'cgf',
            'label'
        ),
        TRUE
    );

SELECT evergreen.upgrade_deps_block_check('0960', :eg_version); 

CREATE TABLE action.usr_circ_history (
    id           BIGSERIAL PRIMARY KEY,
    usr          INTEGER NOT NULL REFERENCES actor.usr(id)
                 DEFERRABLE INITIALLY DEFERRED,
    xact_start   TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    target_copy  BIGINT NOT NULL,
    due_date     TIMESTAMP WITH TIME ZONE NOT NULL,
    checkin_time TIMESTAMP WITH TIME ZONE,
    source_circ  BIGINT REFERENCES action.circulation(id)
                 ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED
);

CREATE OR REPLACE FUNCTION action.maintain_usr_circ_history() 
    RETURNS TRIGGER AS $FUNK$
DECLARE
    cur_circ  BIGINT;
    first_circ BIGINT;
BEGIN                                                                          

    -- Any retention value signifies history is enabled.
    -- This assumes that clearing these values via external 
    -- process deletes the action.usr_circ_history rows.
    -- TODO: replace these settings w/ a single bool setting?
    PERFORM 1 FROM actor.usr_setting 
        WHERE usr = NEW.usr AND value IS NOT NULL AND name IN (
            'history.circ.retention_age', 
            'history.circ.retention_start'
        );

    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    IF TG_OP = 'INSERT' AND NEW.parent_circ IS NULL THEN
        -- Starting a new circulation.  Insert the history row.
        INSERT INTO action.usr_circ_history 
            (usr, xact_start, target_copy, due_date, source_circ)
        VALUES (
            NEW.usr, 
            NEW.xact_start, 
            NEW.target_copy, 
            NEW.due_date, 
            NEW.id
        );

        RETURN NEW;
    END IF;

    -- find the first and last circs in the circ chain 
    -- for the currently modified circ.
    FOR cur_circ IN SELECT id FROM action.circ_chain(NEW.id) LOOP
        IF first_circ IS NULL THEN
            first_circ := cur_circ;
            CONTINUE;
        END IF;
        -- Allow the loop to continue so that at as the loop
        -- completes cur_circ points to the final circulation.
    END LOOP;

    IF NEW.id <> cur_circ THEN
        -- Modifying an intermediate circ.  Ignore it.
        RETURN NEW;
    END IF;

    -- Update the due_date/checkin_time on the history row if the current 
    -- circ is the last circ in the chain and an update is warranted.

    UPDATE action.usr_circ_history 
        SET 
            due_date = NEW.due_date,
            checkin_time = NEW.checkin_time
        WHERE 
            source_circ = first_circ 
            AND (
                due_date <> NEW.due_date OR (
                    (checkin_time IS NULL AND NEW.checkin_time IS NOT NULL) OR
                    (checkin_time IS NOT NULL AND NEW.checkin_time IS NULL) OR
                    (checkin_time <> NEW.checkin_time)
                )
            );
    RETURN NEW;
END;                                                                           
$FUNK$ LANGUAGE PLPGSQL; 

CREATE TRIGGER maintain_usr_circ_history_tgr 
    AFTER INSERT OR UPDATE ON action.circulation 
    FOR EACH ROW EXECUTE PROCEDURE action.maintain_usr_circ_history();

UPDATE action_trigger.hook 
    SET core_type = 'auch' 
    WHERE key ~ '^circ.format.history.'; 

UPDATE action_trigger.event_definition SET template = 
$$
[%- USE date -%]
[%- SET user = target.0.usr -%]
To: [%- params.recipient_email || user.email %]
From: [%- params.sender_email || default_sender %]
Subject: Circulation History

    [% FOR circ IN target %]
            [% helpers.get_copy_bib_basics(circ.target_copy.id).title %]
            Barcode: [% circ.target_copy.barcode %]
            Checked Out: [% date.format(helpers.format_date(circ.xact_start), '%Y-%m-%d') %]
            Due Date: [% date.format(helpers.format_date(circ.due_date), '%Y-%m-%d') %]
            Returned: [%
                date.format(
                    helpers.format_date(circ.checkin_time), '%Y-%m-%d') 
                    IF circ.checkin_time; 
            %]
    [% END %]
$$
WHERE id = 25 AND template = 
$$
[%- USE date -%]
[%- SET user = target.0.usr -%]
To: [%- params.recipient_email || user.email %]
From: [%- params.sender_email || default_sender %]
Subject: Circulation History

    [% FOR circ IN target %]
            [% helpers.get_copy_bib_basics(circ.target_copy.id).title %]
            Barcode: [% circ.target_copy.barcode %]
            Checked Out: [% date.format(helpers.format_date(circ.xact_start), '%Y-%m-%d') %]
            Due Date: [% date.format(helpers.format_date(circ.due_date), '%Y-%m-%d') %]
            Returned: [% date.format(helpers.format_date(circ.checkin_time), '%Y-%m-%d') %]
    [% END %]
$$;

-- avoid TT undef date errors
UPDATE action_trigger.event_definition SET template = 
$$
[%- USE date -%]
<div>
    <style> li { padding: 8px; margin 5px; }</style>
    <div>[% date.format %]</div>
    <br/>

    [% user.family_name %], [% user.first_given_name %]
    <ol>
    [% FOR circ IN target %]
        <li>
            <div>[% helpers.get_copy_bib_basics(circ.target_copy.id).title %]</div>
            <div>Barcode: [% circ.target_copy.barcode %]</div>
            <div>Checked Out: [% date.format(helpers.format_date(circ.xact_start), '%Y-%m-%d') %]</div>
            <div>Due Date: [% date.format(helpers.format_date(circ.due_date), '%Y-%m-%d') %]</div>
            <div>Returned: [%
                date.format(
                    helpers.format_date(circ.checkin_time), '%Y-%m-%d') 
                    IF circ.checkin_time; -%]
            </div>
        </li>
    [% END %]
    </ol>
</div>
$$
WHERE id = 26 AND template = -- only replace template if it matches stock
$$
[%- USE date -%]
<div>
    <style> li { padding: 8px; margin 5px; }</style>
    <div>[% date.format %]</div>
    <br/>

    [% user.family_name %], [% user.first_given_name %]
    <ol>
    [% FOR circ IN target %]
        <li>
            <div>[% helpers.get_copy_bib_basics(circ.target_copy.id).title %]</div>
            <div>Barcode: [% circ.target_copy.barcode %]</div>
            <div>Checked Out: [% date.format(helpers.format_date(circ.xact_start), '%Y-%m-%d') %]</div>
            <div>Due Date: [% date.format(helpers.format_date(circ.due_date), '%Y-%m-%d') %]</div>
            <div>Returned: [% date.format(helpers.format_date(circ.checkin_time), '%Y-%m-%d') %]</div>
        </li>
    [% END %]
    </ol>
</div>
$$;

-- NOTE: ^-- stock CSV template does not include checkin_time, so 
-- no modifications are required.

-- Create circ history rows for existing circ history data.
DO $FUNK$
DECLARE
    cur_usr   INTEGER;
    cur_circ  action.circulation%ROWTYPE;
    last_circ action.circulation%ROWTYPE;
    counter   INTEGER DEFAULT 1;
BEGIN

    RAISE NOTICE 
        'Migrating circ history for % users.  This might take a while...',
        (SELECT COUNT(DISTINCT(au.id)) FROM actor.usr au
            JOIN actor.usr_setting aus ON (aus.usr = au.id)
            WHERE NOT au.deleted AND 
                aus.name ~ '^history.circ.retention_');

    FOR cur_usr IN 
        SELECT DISTINCT(au.id)
            FROM actor.usr au 
            JOIN actor.usr_setting aus ON (aus.usr = au.id)
            WHERE NOT au.deleted AND 
                aus.name ~ '^history.circ.retention_' LOOP

        FOR cur_circ IN SELECT * FROM action.usr_visible_circs(cur_usr) LOOP

            -- Find the last circ in the circ chain.
            SELECT INTO last_circ * 
                FROM action.circ_chain(cur_circ.id) 
                ORDER BY xact_start DESC LIMIT 1;

            -- Create the history row.
            -- It's OK if last_circ = cur_circ
            INSERT INTO action.usr_circ_history 
                (usr, xact_start, target_copy, 
                    due_date, checkin_time, source_circ)
            VALUES (
                cur_circ.usr, 
                cur_circ.xact_start, 
                cur_circ.target_copy, 
                last_circ.due_date, 
                last_circ.checkin_time,
                cur_circ.id
            );

            -- useful for alleviating administrator anxiety.
            IF counter % 10000 = 0 THEN
                RAISE NOTICE 'Migrated history for % total users', counter;
            END IF;

            counter := counter + 1;

        END LOOP;
    END LOOP;

END $FUNK$;

DROP FUNCTION IF EXISTS action.usr_visible_circs (INTEGER);
DROP FUNCTION IF EXISTS action.usr_visible_circ_copies (INTEGER);

-- remove user retention age checks
CREATE OR REPLACE FUNCTION action.purge_circulations () RETURNS INT AS $func$
DECLARE
    org_keep_age    INTERVAL;
    org_use_last    BOOL = false;
    org_age_is_min  BOOL = false;
    org_keep_count  INT;

    keep_age        INTERVAL;

    target_acp      RECORD;
    circ_chain_head action.circulation%ROWTYPE;
    circ_chain_tail action.circulation%ROWTYPE;

    count_purged    INT;
    num_incomplete  INT;

    last_finished   TIMESTAMP WITH TIME ZONE;
BEGIN

    count_purged := 0;

    SELECT value::INTERVAL INTO org_keep_age FROM config.global_flag WHERE name = 'history.circ.retention_age' AND enabled;

    SELECT value::INT INTO org_keep_count FROM config.global_flag WHERE name = 'history.circ.retention_count' AND enabled;
    IF org_keep_count IS NULL THEN
        RETURN count_purged; -- Gimme a count to keep, or I keep them all, forever
    END IF;

    SELECT enabled INTO org_use_last FROM config.global_flag WHERE name = 'history.circ.retention_uses_last_finished';
    SELECT enabled INTO org_age_is_min FROM config.global_flag WHERE name = 'history.circ.retention_age_is_min';

    -- First, find copies with more than keep_count non-renewal circs
    FOR target_acp IN
        SELECT  target_copy,
                COUNT(*) AS total_real_circs
          FROM  action.circulation
          WHERE parent_circ IS NULL
                AND xact_finish IS NOT NULL
          GROUP BY target_copy
          HAVING COUNT(*) > org_keep_count
    LOOP
        -- And, for those, select circs that are finished and older than keep_age
        FOR circ_chain_head IN
            -- For reference, the subquery uses a window function to order the circs newest to oldest and number them
            -- The outer query then uses that information to skip the most recent set the library wants to keep
            -- End result is we don't care what order they come out in, as they are all potentials for deletion.
            SELECT ac.* FROM action.circulation ac JOIN (
              SELECT  rank() OVER (ORDER BY xact_start DESC), ac.id
                FROM  action.circulation ac
                WHERE ac.target_copy = target_acp.target_copy
                  AND ac.parent_circ IS NULL
                ORDER BY ac.xact_start ) ranked USING (id)
                WHERE ranked.rank > org_keep_count
        LOOP

            SELECT * INTO circ_chain_tail FROM action.circ_chain(circ_chain_head.id) ORDER BY xact_start DESC LIMIT 1;
            SELECT COUNT(CASE WHEN xact_finish IS NULL THEN 1 ELSE NULL END), MAX(xact_finish) INTO num_incomplete, last_finished FROM action.circ_chain(circ_chain_head.id);
            CONTINUE WHEN circ_chain_tail.xact_finish IS NULL OR num_incomplete > 0;

            IF NOT org_use_last THEN
                last_finished := circ_chain_tail.xact_finish;
            END IF;

            keep_age := COALESCE( org_keep_age, '2000 years'::INTERVAL );

            IF org_age_is_min THEN
                keep_age := GREATEST( keep_age, org_keep_age );
            END IF;

            CONTINUE WHEN AGE(NOW(), last_finished) < keep_age;

            -- We've passed the purging tests, purge the circ chain starting at the end
            -- A trigger should auto-purge the rest of the chain.
            DELETE FROM action.circulation WHERE id = circ_chain_tail.id;

            count_purged := count_purged + 1;

        END LOOP;
    END LOOP;

    return count_purged;
END;
$func$ LANGUAGE PLPGSQL;

-- delete circ history rows when a user is purged.
CREATE OR REPLACE FUNCTION actor.usr_purge_data(
	src_usr  IN INTEGER,
	specified_dest_usr IN INTEGER
) RETURNS VOID AS $$
DECLARE
	suffix TEXT;
	renamable_row RECORD;
	dest_usr INTEGER;
BEGIN

	IF specified_dest_usr IS NULL THEN
		dest_usr := 1; -- Admin user on stock installs
	ELSE
		dest_usr := specified_dest_usr;
	END IF;

	-- acq.*
	UPDATE acq.fund_allocation SET allocator = dest_usr WHERE allocator = src_usr;
	UPDATE acq.lineitem SET creator = dest_usr WHERE creator = src_usr;
	UPDATE acq.lineitem SET editor = dest_usr WHERE editor = src_usr;
	UPDATE acq.lineitem SET selector = dest_usr WHERE selector = src_usr;
	UPDATE acq.lineitem_note SET creator = dest_usr WHERE creator = src_usr;
	UPDATE acq.lineitem_note SET editor = dest_usr WHERE editor = src_usr;
	DELETE FROM acq.lineitem_usr_attr_definition WHERE usr = src_usr;

	-- Update with a rename to avoid collisions
	FOR renamable_row in
		SELECT id, name
		FROM   acq.picklist
		WHERE  owner = src_usr
	LOOP
		suffix := ' (' || src_usr || ')';
		LOOP
			BEGIN
				UPDATE  acq.picklist
				SET     owner = dest_usr, name = name || suffix
				WHERE   id = renamable_row.id;
			EXCEPTION WHEN unique_violation THEN
				suffix := suffix || ' ';
				CONTINUE;
			END;
			EXIT;
		END LOOP;
	END LOOP;

	UPDATE acq.picklist SET creator = dest_usr WHERE creator = src_usr;
	UPDATE acq.picklist SET editor = dest_usr WHERE editor = src_usr;
	UPDATE acq.po_note SET creator = dest_usr WHERE creator = src_usr;
	UPDATE acq.po_note SET editor = dest_usr WHERE editor = src_usr;
	UPDATE acq.purchase_order SET owner = dest_usr WHERE owner = src_usr;
	UPDATE acq.purchase_order SET creator = dest_usr WHERE creator = src_usr;
	UPDATE acq.purchase_order SET editor = dest_usr WHERE editor = src_usr;
	UPDATE acq.claim_event SET creator = dest_usr WHERE creator = src_usr;

	-- action.*
	DELETE FROM action.circulation WHERE usr = src_usr;
	UPDATE action.circulation SET circ_staff = dest_usr WHERE circ_staff = src_usr;
	UPDATE action.circulation SET checkin_staff = dest_usr WHERE checkin_staff = src_usr;
	UPDATE action.hold_notification SET notify_staff = dest_usr WHERE notify_staff = src_usr;
	UPDATE action.hold_request SET fulfillment_staff = dest_usr WHERE fulfillment_staff = src_usr;
	UPDATE action.hold_request SET requestor = dest_usr WHERE requestor = src_usr;
	DELETE FROM action.hold_request WHERE usr = src_usr;
	UPDATE action.in_house_use SET staff = dest_usr WHERE staff = src_usr;
	UPDATE action.non_cat_in_house_use SET staff = dest_usr WHERE staff = src_usr;
	DELETE FROM action.non_cataloged_circulation WHERE patron = src_usr;
	UPDATE action.non_cataloged_circulation SET staff = dest_usr WHERE staff = src_usr;
	DELETE FROM action.survey_response WHERE usr = src_usr;
	UPDATE action.fieldset SET owner = dest_usr WHERE owner = src_usr;
    DELETE FROM action.usr_circ_history WHERE usr = src_usr;

	-- actor.*
	DELETE FROM actor.card WHERE usr = src_usr;
	DELETE FROM actor.stat_cat_entry_usr_map WHERE target_usr = src_usr;

	-- The following update is intended to avoid transient violations of a foreign
	-- key constraint, whereby actor.usr_address references itself.  It may not be
	-- necessary, but it does no harm.
	UPDATE actor.usr_address SET replaces = NULL
		WHERE usr = src_usr AND replaces IS NOT NULL;
	DELETE FROM actor.usr_address WHERE usr = src_usr;
	DELETE FROM actor.usr_note WHERE usr = src_usr;
	UPDATE actor.usr_note SET creator = dest_usr WHERE creator = src_usr;
	DELETE FROM actor.usr_org_unit_opt_in WHERE usr = src_usr;
	UPDATE actor.usr_org_unit_opt_in SET staff = dest_usr WHERE staff = src_usr;
	DELETE FROM actor.usr_setting WHERE usr = src_usr;
	DELETE FROM actor.usr_standing_penalty WHERE usr = src_usr;
	UPDATE actor.usr_standing_penalty SET staff = dest_usr WHERE staff = src_usr;

	-- asset.*
	UPDATE asset.call_number SET creator = dest_usr WHERE creator = src_usr;
	UPDATE asset.call_number SET editor = dest_usr WHERE editor = src_usr;
	UPDATE asset.call_number_note SET creator = dest_usr WHERE creator = src_usr;
	UPDATE asset.copy SET creator = dest_usr WHERE creator = src_usr;
	UPDATE asset.copy SET editor = dest_usr WHERE editor = src_usr;
	UPDATE asset.copy_note SET creator = dest_usr WHERE creator = src_usr;

	-- auditor.*
	DELETE FROM auditor.actor_usr_address_history WHERE id = src_usr;
	DELETE FROM auditor.actor_usr_history WHERE id = src_usr;
	UPDATE auditor.asset_call_number_history SET creator = dest_usr WHERE creator = src_usr;
	UPDATE auditor.asset_call_number_history SET editor  = dest_usr WHERE editor  = src_usr;
	UPDATE auditor.asset_copy_history SET creator = dest_usr WHERE creator = src_usr;
	UPDATE auditor.asset_copy_history SET editor  = dest_usr WHERE editor  = src_usr;
	UPDATE auditor.biblio_record_entry_history SET creator = dest_usr WHERE creator = src_usr;
	UPDATE auditor.biblio_record_entry_history SET editor  = dest_usr WHERE editor  = src_usr;

	-- biblio.*
	UPDATE biblio.record_entry SET creator = dest_usr WHERE creator = src_usr;
	UPDATE biblio.record_entry SET editor = dest_usr WHERE editor = src_usr;
	UPDATE biblio.record_note SET creator = dest_usr WHERE creator = src_usr;
	UPDATE biblio.record_note SET editor = dest_usr WHERE editor = src_usr;

	-- container.*
	-- Update buckets with a rename to avoid collisions
	FOR renamable_row in
		SELECT id, name
		FROM   container.biblio_record_entry_bucket
		WHERE  owner = src_usr
	LOOP
		suffix := ' (' || src_usr || ')';
		LOOP
			BEGIN
				UPDATE  container.biblio_record_entry_bucket
				SET     owner = dest_usr, name = name || suffix
				WHERE   id = renamable_row.id;
			EXCEPTION WHEN unique_violation THEN
				suffix := suffix || ' ';
				CONTINUE;
			END;
			EXIT;
		END LOOP;
	END LOOP;

	FOR renamable_row in
		SELECT id, name
		FROM   container.call_number_bucket
		WHERE  owner = src_usr
	LOOP
		suffix := ' (' || src_usr || ')';
		LOOP
			BEGIN
				UPDATE  container.call_number_bucket
				SET     owner = dest_usr, name = name || suffix
				WHERE   id = renamable_row.id;
			EXCEPTION WHEN unique_violation THEN
				suffix := suffix || ' ';
				CONTINUE;
			END;
			EXIT;
		END LOOP;
	END LOOP;

	FOR renamable_row in
		SELECT id, name
		FROM   container.copy_bucket
		WHERE  owner = src_usr
	LOOP
		suffix := ' (' || src_usr || ')';
		LOOP
			BEGIN
				UPDATE  container.copy_bucket
				SET     owner = dest_usr, name = name || suffix
				WHERE   id = renamable_row.id;
			EXCEPTION WHEN unique_violation THEN
				suffix := suffix || ' ';
				CONTINUE;
			END;
			EXIT;
		END LOOP;
	END LOOP;

	FOR renamable_row in
		SELECT id, name
		FROM   container.user_bucket
		WHERE  owner = src_usr
	LOOP
		suffix := ' (' || src_usr || ')';
		LOOP
			BEGIN
				UPDATE  container.user_bucket
				SET     owner = dest_usr, name = name || suffix
				WHERE   id = renamable_row.id;
			EXCEPTION WHEN unique_violation THEN
				suffix := suffix || ' ';
				CONTINUE;
			END;
			EXIT;
		END LOOP;
	END LOOP;

	DELETE FROM container.user_bucket_item WHERE target_user = src_usr;

	-- money.*
	DELETE FROM money.billable_xact WHERE usr = src_usr;
	DELETE FROM money.collections_tracker WHERE usr = src_usr;
	UPDATE money.collections_tracker SET collector = dest_usr WHERE collector = src_usr;

	-- permission.*
	DELETE FROM permission.usr_grp_map WHERE usr = src_usr;
	DELETE FROM permission.usr_object_perm_map WHERE usr = src_usr;
	DELETE FROM permission.usr_perm_map WHERE usr = src_usr;
	DELETE FROM permission.usr_work_ou_map WHERE usr = src_usr;

	-- reporter.*
	-- Update with a rename to avoid collisions
	BEGIN
		FOR renamable_row in
			SELECT id, name
			FROM   reporter.output_folder
			WHERE  owner = src_usr
		LOOP
			suffix := ' (' || src_usr || ')';
			LOOP
				BEGIN
					UPDATE  reporter.output_folder
					SET     owner = dest_usr, name = name || suffix
					WHERE   id = renamable_row.id;
				EXCEPTION WHEN unique_violation THEN
					suffix := suffix || ' ';
					CONTINUE;
				END;
				EXIT;
			END LOOP;
		END LOOP;
	EXCEPTION WHEN undefined_table THEN
		-- do nothing
	END;

	BEGIN
		UPDATE reporter.report SET owner = dest_usr WHERE owner = src_usr;
	EXCEPTION WHEN undefined_table THEN
		-- do nothing
	END;

	-- Update with a rename to avoid collisions
	BEGIN
		FOR renamable_row in
			SELECT id, name
			FROM   reporter.report_folder
			WHERE  owner = src_usr
		LOOP
			suffix := ' (' || src_usr || ')';
			LOOP
				BEGIN
					UPDATE  reporter.report_folder
					SET     owner = dest_usr, name = name || suffix
					WHERE   id = renamable_row.id;
				EXCEPTION WHEN unique_violation THEN
					suffix := suffix || ' ';
					CONTINUE;
				END;
				EXIT;
			END LOOP;
		END LOOP;
	EXCEPTION WHEN undefined_table THEN
		-- do nothing
	END;

	BEGIN
		UPDATE reporter.schedule SET runner = dest_usr WHERE runner = src_usr;
	EXCEPTION WHEN undefined_table THEN
		-- do nothing
	END;

	BEGIN
		UPDATE reporter.template SET owner = dest_usr WHERE owner = src_usr;
	EXCEPTION WHEN undefined_table THEN
		-- do nothing
	END;

	-- Update with a rename to avoid collisions
	BEGIN
		FOR renamable_row in
			SELECT id, name
			FROM   reporter.template_folder
			WHERE  owner = src_usr
		LOOP
			suffix := ' (' || src_usr || ')';
			LOOP
				BEGIN
					UPDATE  reporter.template_folder
					SET     owner = dest_usr, name = name || suffix
					WHERE   id = renamable_row.id;
				EXCEPTION WHEN unique_violation THEN
					suffix := suffix || ' ';
					CONTINUE;
				END;
				EXIT;
			END LOOP;
		END LOOP;
	EXCEPTION WHEN undefined_table THEN
	-- do nothing
	END;

	-- vandelay.*
	-- Update with a rename to avoid collisions
	FOR renamable_row in
		SELECT id, name
		FROM   vandelay.queue
		WHERE  owner = src_usr
	LOOP
		suffix := ' (' || src_usr || ')';
		LOOP
			BEGIN
				UPDATE  vandelay.queue
				SET     owner = dest_usr, name = name || suffix
				WHERE   id = renamable_row.id;
			EXCEPTION WHEN unique_violation THEN
				suffix := suffix || ' ';
				CONTINUE;
			END;
			EXIT;
		END LOOP;
	END LOOP;

    -- NULL-ify addresses last so other cleanup (e.g. circ anonymization)
    -- can access the information before deletion.
	UPDATE actor.usr SET
		active = FALSE,
		card = NULL,
		mailing_address = NULL,
		billing_address = NULL
	WHERE id = src_usr;

END;
$$ LANGUAGE plpgsql;

SELECT evergreen.upgrade_deps_block_check('0961', :eg_version);

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE actor.passwd_type (
    code        TEXT PRIMARY KEY,
    name        TEXT UNIQUE NOT NULL,
    login       BOOLEAN NOT NULL DEFAULT FALSE,
    regex       TEXT,   -- pending
    crypt_algo  TEXT,   -- e.g. 'bf'

    -- gen_salt() iter count used with each new salt.
    -- A non-NULL value for iter_count is our indication the 
    -- password is salted and encrypted via crypt()
    iter_count  INTEGER CHECK (iter_count IS NULL OR iter_count > 0)
);

CREATE TABLE actor.passwd (
    id          SERIAL PRIMARY KEY,
    usr         INTEGER NOT NULL REFERENCES actor.usr(id)
                ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
    salt        TEXT, -- will be NULL for non-crypt'ed passwords
    passwd      TEXT NOT NULL,
    passwd_type TEXT NOT NULL REFERENCES actor.passwd_type(code)
                DEFERRABLE INITIALLY DEFERRED,
    create_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    edit_date   TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    CONSTRAINT  passwd_type_once_per_user UNIQUE (usr, passwd_type)
);

CREATE OR REPLACE FUNCTION actor.create_salt(pw_type TEXT)
    RETURNS TEXT AS $$
DECLARE
    type_row actor.passwd_type%ROWTYPE;
BEGIN
    /* Returns a new salt based on the passwd_type encryption settings.
     * Returns NULL If the password type is not crypt()'ed.
     */

    SELECT INTO type_row * FROM actor.passwd_type WHERE code = pw_type;

    IF NOT FOUND THEN
        RETURN EXCEPTION 'No such password type: %', pw_type;
    END IF;

    IF type_row.iter_count IS NULL THEN
        -- This password type is unsalted.  That's OK.
        RETURN NULL;
    END IF;

    RETURN gen_salt(type_row.crypt_algo, type_row.iter_count);
END;
$$ LANGUAGE PLPGSQL;


/* 
    TODO: when a user changes their password in the application, the
    app layer has access to the bare password.  At that point, we have
    the opportunity to store the new password without the MD5(MD5())
    intermediate hashing.  Do we care?  We would need a way to indicate
    which passwords have the legacy intermediate hashing and which don't
    so the app layer would know whether it should perform the intermediate
    hashing.  In either event, with the exception of migrate_passwd(), the
    DB functions know or care nothing about intermediate hashing.  Every
    password is just a value that may or may not be internally crypt'ed. 
*/

CREATE OR REPLACE FUNCTION actor.set_passwd(
    pw_usr INTEGER, pw_type TEXT, new_pass TEXT, new_salt TEXT DEFAULT NULL)
    RETURNS BOOLEAN AS $$
DECLARE
    pw_salt TEXT;
    pw_text TEXT;
BEGIN
    /* Sets the password value, creating a new actor.passwd row if needed.
     * If the password type supports it, the new_pass value is crypt()'ed.
     * For crypt'ed passwords, the salt comes from one of 3 places in order:
     * new_salt (if present), existing salt (if present), newly created 
     * salt.
     */

    IF new_salt IS NOT NULL THEN
        pw_salt := new_salt;
    ELSE 
        pw_salt := actor.get_salt(pw_usr, pw_type);

        IF pw_salt IS NULL THEN
            /* We have no salt for this user + type.  Assume they want a 
             * new salt.  If this type is unsalted, create_salt() will 
             * return NULL. */
            pw_salt := actor.create_salt(pw_type);
        END IF;
    END IF;

    IF pw_salt IS NULL THEN 
        pw_text := new_pass; -- unsalted, use as-is.
    ELSE
        pw_text := CRYPT(new_pass, pw_salt);
    END IF;

    UPDATE actor.passwd 
        SET passwd = pw_text, salt = pw_salt, edit_date = NOW()
        WHERE usr = pw_usr AND passwd_type = pw_type;

    IF NOT FOUND THEN
        -- no password row exists for this user + type.  Create one.
        INSERT INTO actor.passwd (usr, passwd_type, salt, passwd) 
            VALUES (pw_usr, pw_type, pw_salt, pw_text);
    END IF;

    RETURN TRUE;
END;
$$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION actor.get_salt(pw_usr INTEGER, pw_type TEXT)
    RETURNS TEXT AS $$
DECLARE
    pw_salt TEXT;
    type_row actor.passwd_type%ROWTYPE;
BEGIN
    /* Returns the salt for the requested user + type.  If the password 
     * type of "main" is requested and no password exists in actor.passwd, 
     * the user's existing password is migrated and the new salt is returned.
     * Returns NULL if the password type is not crypt'ed (iter_count is NULL).
     */

    SELECT INTO pw_salt salt FROM actor.passwd 
        WHERE usr = pw_usr AND passwd_type = pw_type;

    IF FOUND THEN
        RETURN pw_salt;
    END IF;

    IF pw_type = 'main' THEN
        -- Main password has not yet been migrated. 
        -- Do it now and return the newly created salt.
        RETURN actor.migrate_passwd(pw_usr);
    END IF;

    -- We have no salt to return.  actor.create_salt() needed.
    RETURN NULL;
END;
$$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION 
    actor.migrate_passwd(pw_usr INTEGER) RETURNS TEXT AS $$
DECLARE
    pw_salt TEXT;
    usr_row actor.usr%ROWTYPE;
BEGIN
    /* Migrates legacy actor.usr.passwd value to actor.passwd with 
     * a password type 'main' and returns the new salt.  For backwards
     * compatibility with existing CHAP-style API's, we perform a 
     * layer of intermediate MD5(MD5()) hashing.  This is intermediate
     * hashing is not required of other passwords.
     */

    -- Avoid calling get_salt() here, because it may result in a 
    -- migrate_passwd() call, creating a loop.
    SELECT INTO pw_salt salt FROM actor.passwd 
        WHERE usr = pw_usr AND passwd_type = 'main';

    -- Only migrate passwords that have not already been migrated.
    IF FOUND THEN
        RETURN pw_salt;
    END IF;

    SELECT INTO usr_row * FROM actor.usr WHERE id = pw_usr;

    pw_salt := actor.create_salt('main');

    PERFORM actor.set_passwd(
        pw_usr, 'main', MD5(pw_salt || usr_row.passwd), pw_salt);

    -- clear the existing password
    UPDATE actor.usr SET passwd = '' WHERE id = usr_row.id;

    RETURN pw_salt;
END;
$$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION 
    actor.verify_passwd(pw_usr INTEGER, pw_type TEXT, test_passwd TEXT) 
    RETURNS BOOLEAN AS $$
DECLARE
    pw_salt TEXT;
BEGIN
    /* Returns TRUE if the password provided matches the in-db password.  
     * If the password type is salted, we compare the output of CRYPT().
     * NOTE: test_passwd is MD5(salt || MD5(password)) for legacy 
     * 'main' passwords.
     */

    SELECT INTO pw_salt salt FROM actor.passwd 
        WHERE usr = pw_usr AND passwd_type = pw_type;

    IF NOT FOUND THEN
        -- no such password
        RETURN FALSE;
    END IF;

    IF pw_salt IS NULL THEN
        -- Password is unsalted, compare the un-CRYPT'ed values.
        RETURN EXISTS (
            SELECT TRUE FROM actor.passwd WHERE 
                usr = pw_usr AND
                passwd_type = pw_type AND
                passwd = test_passwd
        );
    END IF;

    RETURN EXISTS (
        SELECT TRUE FROM actor.passwd WHERE 
            usr = pw_usr AND
            passwd_type = pw_type AND
            passwd = CRYPT(test_passwd, pw_salt)
    );
END;
$$ STRICT LANGUAGE PLPGSQL;

--- DATA ----------------------

INSERT INTO actor.passwd_type 
    (code, name, login, crypt_algo, iter_count) 
    VALUES ('main', 'Main Login Password', TRUE, 'bf', 10);

SELECT evergreen.upgrade_deps_block_check('0962', :eg_version);

ALTER TABLE vandelay.import_item_attr_definition
    ADD COLUMN parts_data TEXT;

ALTER TABLE vandelay.import_item
    ADD COLUMN parts_data TEXT;

CREATE OR REPLACE FUNCTION vandelay.ingest_items ( import_id BIGINT, attr_def_id BIGINT ) RETURNS SETOF vandelay.import_item AS $$
DECLARE

    owning_lib      TEXT;
    circ_lib        TEXT;
    call_number     TEXT;
    copy_number     TEXT;
    status          TEXT;
    location        TEXT;
    circulate       TEXT;
    deposit         TEXT;
    deposit_amount  TEXT;
    ref             TEXT;
    holdable        TEXT;
    price           TEXT;
    barcode         TEXT;
    circ_modifier   TEXT;
    circ_as_type    TEXT;
    alert_message   TEXT;
    opac_visible    TEXT;
    pub_note        TEXT;
    priv_note       TEXT;
    internal_id     TEXT;
    stat_cat_data   TEXT;
    parts_data      TEXT;

    attr_def        RECORD;
    tmp_attr_set    RECORD;
    attr_set        vandelay.import_item%ROWTYPE;

    xpaths          TEXT[];
    tmp_str         TEXT;

BEGIN

    SELECT * INTO attr_def FROM vandelay.import_item_attr_definition WHERE id = attr_def_id;

    IF FOUND THEN

        attr_set.definition := attr_def.id;

        -- Build the combined XPath

        owning_lib :=
            CASE
                WHEN attr_def.owning_lib IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.owning_lib ) = 1 THEN '*[@code="' || attr_def.owning_lib || '"]'
                ELSE '*' || attr_def.owning_lib
            END;

        circ_lib :=
            CASE
                WHEN attr_def.circ_lib IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.circ_lib ) = 1 THEN '*[@code="' || attr_def.circ_lib || '"]'
                ELSE '*' || attr_def.circ_lib
            END;

        call_number :=
            CASE
                WHEN attr_def.call_number IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.call_number ) = 1 THEN '*[@code="' || attr_def.call_number || '"]'
                ELSE '*' || attr_def.call_number
            END;

        copy_number :=
            CASE
                WHEN attr_def.copy_number IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.copy_number ) = 1 THEN '*[@code="' || attr_def.copy_number || '"]'
                ELSE '*' || attr_def.copy_number
            END;

        status :=
            CASE
                WHEN attr_def.status IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.status ) = 1 THEN '*[@code="' || attr_def.status || '"]'
                ELSE '*' || attr_def.status
            END;

        location :=
            CASE
                WHEN attr_def.location IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.location ) = 1 THEN '*[@code="' || attr_def.location || '"]'
                ELSE '*' || attr_def.location
            END;

        circulate :=
            CASE
                WHEN attr_def.circulate IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.circulate ) = 1 THEN '*[@code="' || attr_def.circulate || '"]'
                ELSE '*' || attr_def.circulate
            END;

        deposit :=
            CASE
                WHEN attr_def.deposit IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.deposit ) = 1 THEN '*[@code="' || attr_def.deposit || '"]'
                ELSE '*' || attr_def.deposit
            END;

        deposit_amount :=
            CASE
                WHEN attr_def.deposit_amount IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.deposit_amount ) = 1 THEN '*[@code="' || attr_def.deposit_amount || '"]'
                ELSE '*' || attr_def.deposit_amount
            END;

        ref :=
            CASE
                WHEN attr_def.ref IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.ref ) = 1 THEN '*[@code="' || attr_def.ref || '"]'
                ELSE '*' || attr_def.ref
            END;

        holdable :=
            CASE
                WHEN attr_def.holdable IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.holdable ) = 1 THEN '*[@code="' || attr_def.holdable || '"]'
                ELSE '*' || attr_def.holdable
            END;

        price :=
            CASE
                WHEN attr_def.price IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.price ) = 1 THEN '*[@code="' || attr_def.price || '"]'
                ELSE '*' || attr_def.price
            END;

        barcode :=
            CASE
                WHEN attr_def.barcode IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.barcode ) = 1 THEN '*[@code="' || attr_def.barcode || '"]'
                ELSE '*' || attr_def.barcode
            END;

        circ_modifier :=
            CASE
                WHEN attr_def.circ_modifier IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.circ_modifier ) = 1 THEN '*[@code="' || attr_def.circ_modifier || '"]'
                ELSE '*' || attr_def.circ_modifier
            END;

        circ_as_type :=
            CASE
                WHEN attr_def.circ_as_type IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.circ_as_type ) = 1 THEN '*[@code="' || attr_def.circ_as_type || '"]'
                ELSE '*' || attr_def.circ_as_type
            END;

        alert_message :=
            CASE
                WHEN attr_def.alert_message IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.alert_message ) = 1 THEN '*[@code="' || attr_def.alert_message || '"]'
                ELSE '*' || attr_def.alert_message
            END;

        opac_visible :=
            CASE
                WHEN attr_def.opac_visible IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.opac_visible ) = 1 THEN '*[@code="' || attr_def.opac_visible || '"]'
                ELSE '*' || attr_def.opac_visible
            END;

        pub_note :=
            CASE
                WHEN attr_def.pub_note IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.pub_note ) = 1 THEN '*[@code="' || attr_def.pub_note || '"]'
                ELSE '*' || attr_def.pub_note
            END;
        priv_note :=
            CASE
                WHEN attr_def.priv_note IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.priv_note ) = 1 THEN '*[@code="' || attr_def.priv_note || '"]'
                ELSE '*' || attr_def.priv_note
            END;

        internal_id :=
            CASE
                WHEN attr_def.internal_id IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.internal_id ) = 1 THEN '*[@code="' || attr_def.internal_id || '"]'
                ELSE '*' || attr_def.internal_id
            END;

        stat_cat_data :=
            CASE
                WHEN attr_def.stat_cat_data IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.stat_cat_data ) = 1 THEN '*[@code="' || attr_def.stat_cat_data || '"]'
                ELSE '*' || attr_def.stat_cat_data
            END;

        parts_data :=
            CASE
                WHEN attr_def.parts_data IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.parts_data ) = 1 THEN '*[@code="' || attr
                ELSE '*' || attr_def.parts_data
            END;



        xpaths := ARRAY[owning_lib, circ_lib, call_number, copy_number, status, location, circulate,
                        deposit, deposit_amount, ref, holdable, price, barcode, circ_modifier, circ_as_type,
                        alert_message, pub_note, priv_note, internal_id, stat_cat_data, parts_data, opac_visible];

        FOR tmp_attr_set IN
                SELECT  *
                  FROM  oils_xpath_tag_to_table( (SELECT marc FROM vandelay.queued_bib_record WHERE id = import_id), attr_def.tag, xpaths)
                            AS t( ol TEXT, clib TEXT, cn TEXT, cnum TEXT, cs TEXT, cl TEXT, circ TEXT,
                                  dep TEXT, dep_amount TEXT, r TEXT, hold TEXT, pr TEXT, bc TEXT, circ_mod TEXT,
                                  circ_as TEXT, amessage TEXT, note TEXT, pnote TEXT, internal_id TEXT,
                                  stat_cat_data TEXT, parts_data TEXT, opac_vis TEXT )
        LOOP

            attr_set.import_error := NULL;
            attr_set.error_detail := NULL;
            attr_set.deposit_amount := NULL;
            attr_set.copy_number := NULL;
            attr_set.price := NULL;
            attr_set.circ_modifier := NULL;
            attr_set.location := NULL;
            attr_set.barcode := NULL;
            attr_set.call_number := NULL;

            IF tmp_attr_set.pr != '' THEN
                tmp_str = REGEXP_REPLACE(tmp_attr_set.pr, E'[^0-9\\.]', '', 'g');
                IF tmp_str = '' THEN
                    attr_set.import_error := 'import.item.invalid.price';
                    attr_set.error_detail := tmp_attr_set.pr; -- original value
                    RETURN NEXT attr_set; CONTINUE;
                END IF;
                attr_set.price := tmp_str::NUMERIC(8,2);
            END IF;

            IF tmp_attr_set.dep_amount != '' THEN
                tmp_str = REGEXP_REPLACE(tmp_attr_set.dep_amount, E'[^0-9\\.]', '', 'g');
                IF tmp_str = '' THEN
                    attr_set.import_error := 'import.item.invalid.deposit_amount';
                    attr_set.error_detail := tmp_attr_set.dep_amount;
                    RETURN NEXT attr_set; CONTINUE;
                END IF;
                attr_set.deposit_amount := tmp_str::NUMERIC(8,2);
            END IF;

            IF tmp_attr_set.cnum != '' THEN
                tmp_str = REGEXP_REPLACE(tmp_attr_set.cnum, E'[^0-9]', '', 'g');
                IF tmp_str = '' THEN
                    attr_set.import_error := 'import.item.invalid.copy_number';
                    attr_set.error_detail := tmp_attr_set.cnum;
                    RETURN NEXT attr_set; CONTINUE;
                END IF;
                attr_set.copy_number := tmp_str::INT;
            END IF;

            IF tmp_attr_set.ol != '' THEN
                SELECT id INTO attr_set.owning_lib FROM actor.org_unit WHERE shortname = UPPER(tmp_attr_set.ol); -- INT
                IF NOT FOUND THEN
                    attr_set.import_error := 'import.item.invalid.owning_lib';
                    attr_set.error_detail := tmp_attr_set.ol;
                    RETURN NEXT attr_set; CONTINUE;
                END IF;
            END IF;

            IF tmp_attr_set.clib != '' THEN
                SELECT id INTO attr_set.circ_lib FROM actor.org_unit WHERE shortname = UPPER(tmp_attr_set.clib); -- INT
                IF NOT FOUND THEN
                    attr_set.import_error := 'import.item.invalid.circ_lib';
                    attr_set.error_detail := tmp_attr_set.clib;
                    RETURN NEXT attr_set; CONTINUE;
                END IF;
            END IF;

            IF tmp_attr_set.cs != '' THEN
                SELECT id INTO attr_set.status FROM config.copy_status WHERE LOWER(name) = LOWER(tmp_attr_set.cs); -- INT
                IF NOT FOUND THEN
                    attr_set.import_error := 'import.item.invalid.status';
                    attr_set.error_detail := tmp_attr_set.cs;
                    RETURN NEXT attr_set; CONTINUE;
                END IF;
            END IF;

            IF COALESCE(tmp_attr_set.circ_mod, '') = '' THEN

                -- no circ mod defined, see if we should apply a default
                SELECT INTO attr_set.circ_modifier TRIM(BOTH '"' FROM value)
                    FROM actor.org_unit_ancestor_setting(
                        'vandelay.item.circ_modifier.default',
                        attr_set.owning_lib
                    );

                -- make sure the value from the org setting is still valid
                PERFORM 1 FROM config.circ_modifier WHERE code = attr_set.circ_modifier;
                IF NOT FOUND THEN
                    attr_set.import_error := 'import.item.invalid.circ_modifier';
                    attr_set.error_detail := tmp_attr_set.circ_mod;
                    RETURN NEXT attr_set; CONTINUE;
                END IF;

            ELSE

                SELECT code INTO attr_set.circ_modifier FROM config.circ_modifier WHERE code = tmp_attr_set.circ_mod;
                IF NOT FOUND THEN
                    attr_set.import_error := 'import.item.invalid.circ_modifier';
                    attr_set.error_detail := tmp_attr_set.circ_mod;
                    RETURN NEXT attr_set; CONTINUE;
                END IF;
            END IF;

            IF tmp_attr_set.circ_as != '' THEN
                SELECT code INTO attr_set.circ_as_type FROM config.coded_value_map WHERE ctype = 'item_type' AND code = tmp_attr_set.circ_as;
                IF NOT FOUND THEN
                    attr_set.import_error := 'import.item.invalid.circ_as_type';
                    attr_set.error_detail := tmp_attr_set.circ_as;
                    RETURN NEXT attr_set; CONTINUE;
                END IF;
            END IF;

            IF COALESCE(tmp_attr_set.cl, '') = '' THEN
                -- no location specified, see if we should apply a default

                SELECT INTO attr_set.location TRIM(BOTH '"' FROM value)
                    FROM actor.org_unit_ancestor_setting(
                        'vandelay.item.copy_location.default',
                        attr_set.owning_lib
                    );

                -- make sure the value from the org setting is still valid
                PERFORM 1 FROM asset.copy_location WHERE id = attr_set.location;
                IF NOT FOUND THEN
                    attr_set.import_error := 'import.item.invalid.location';
                    attr_set.error_detail := tmp_attr_set.cs;
                    RETURN NEXT attr_set; CONTINUE;
                END IF;
            ELSE

                -- search up the org unit tree for a matching copy location
                WITH RECURSIVE anscestor_depth AS (
                    SELECT  ou.id,
                        out.depth AS depth,
                        ou.parent_ou
                    FROM  actor.org_unit ou
                        JOIN actor.org_unit_type out ON (out.id = ou.ou_type)
                    WHERE ou.id = COALESCE(attr_set.owning_lib, attr_set.circ_lib)
                        UNION ALL
                    SELECT  ou.id,
                        out.depth,
                        ou.parent_ou
                    FROM  actor.org_unit ou
                        JOIN actor.org_unit_type out ON (out.id = ou.ou_type)
                        JOIN anscestor_depth ot ON (ot.parent_ou = ou.id)
                ) SELECT  cpl.id INTO attr_set.location
                    FROM  anscestor_depth a
                        JOIN asset.copy_location cpl ON (cpl.owning_lib = a.id)
                    WHERE LOWER(cpl.name) = LOWER(tmp_attr_set.cl)
                    ORDER BY a.depth DESC
                    LIMIT 1;

                IF NOT FOUND THEN
                    attr_set.import_error := 'import.item.invalid.location';
                    attr_set.error_detail := tmp_attr_set.cs;
                    RETURN NEXT attr_set; CONTINUE;
                END IF;
            END IF;

            attr_set.circulate      :=
                LOWER( SUBSTRING( tmp_attr_set.circ, 1, 1)) IN ('t','y','1')
                OR LOWER(tmp_attr_set.circ) = 'circulating'; -- BOOL

            attr_set.deposit        :=
                LOWER( SUBSTRING( tmp_attr_set.dep, 1, 1 ) ) IN ('t','y','1')
                OR LOWER(tmp_attr_set.dep) = 'deposit'; -- BOOL

            attr_set.holdable       :=
                LOWER( SUBSTRING( tmp_attr_set.hold, 1, 1 ) ) IN ('t','y','1')
                OR LOWER(tmp_attr_set.hold) = 'holdable'; -- BOOL

            attr_set.opac_visible   :=
                LOWER( SUBSTRING( tmp_attr_set.opac_vis, 1, 1 ) ) IN ('t','y','1')
                OR LOWER(tmp_attr_set.opac_vis) = 'visible'; -- BOOL

            attr_set.ref            :=
                LOWER( SUBSTRING( tmp_attr_set.r, 1, 1 ) ) IN ('t','y','1')
                OR LOWER(tmp_attr_set.r) = 'reference'; -- BOOL

            attr_set.call_number    := tmp_attr_set.cn; -- TEXT
            attr_set.barcode        := tmp_attr_set.bc; -- TEXT,
            attr_set.alert_message  := tmp_attr_set.amessage; -- TEXT,
            attr_set.pub_note       := tmp_attr_set.note; -- TEXT,
            attr_set.priv_note      := tmp_attr_set.pnote; -- TEXT,
            attr_set.alert_message  := tmp_attr_set.amessage; -- TEXT,
            attr_set.internal_id    := tmp_attr_set.internal_id::BIGINT;
            attr_set.stat_cat_data  := tmp_attr_set.stat_cat_data; -- TEXT,
            attr_set.parts_data     := tmp_attr_set.parts_data; -- TEXT,

            RETURN NEXT attr_set;

        END LOOP;

    END IF;

    RETURN;

END;
$$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION vandelay.ingest_bib_items ( ) RETURNS TRIGGER AS $func$
DECLARE
    attr_def    BIGINT;
    item_data   vandelay.import_item%ROWTYPE;
BEGIN

    IF TG_OP IN ('INSERT','UPDATE') AND NEW.imported_as IS NOT NULL THEN
        RETURN NEW;
    END IF;

    SELECT item_attr_def INTO attr_def FROM vandelay.bib_queue WHERE id = NEW.queue;

    FOR item_data IN SELECT * FROM vandelay.ingest_items( NEW.id::BIGINT, attr_def ) LOOP
        INSERT INTO vandelay.import_item (
            record,
            definition,
            owning_lib,
            circ_lib,
            call_number,
            copy_number,
            status,
            location,
            circulate,
            deposit,
            deposit_amount,
            ref,
            holdable,
            price,
            barcode,
            circ_modifier,
            circ_as_type,
            alert_message,
            pub_note,
            priv_note,
            internal_id,
            opac_visible,
            stat_cat_data,
            parts_data,
            import_error,
            error_detail
        ) VALUES (
            NEW.id,
            item_data.definition,
            item_data.owning_lib,
            item_data.circ_lib,
            item_data.call_number,
            item_data.copy_number,
            item_data.status,
            item_data.location,
            item_data.circulate,
            item_data.deposit,
            item_data.deposit_amount,
            item_data.ref,
            item_data.holdable,
            item_data.price,
            item_data.barcode,
            item_data.circ_modifier,
            item_data.circ_as_type,
            item_data.alert_message,
            item_data.pub_note,
            item_data.priv_note,
            item_data.internal_id,
            item_data.opac_visible,
            item_data.stat_cat_data,
            item_data.parts_data,
            item_data.import_error,
            item_data.error_detail
        );
    END LOOP;

    RETURN NULL;
END;
$func$ LANGUAGE PLPGSQL;

SELECT evergreen.upgrade_deps_block_check('0963', :eg_version);

ALTER TABLE config.z3950_index_field_map DROP CONSTRAINT "valid_z3950_attr_type";

DROP FUNCTION evergreen.z3950_attr_name_is_valid(text);

CREATE OR REPLACE FUNCTION evergreen.z3950_attr_name_is_valid() RETURNS TRIGGER AS $func$
BEGIN

  PERFORM * FROM config.z3950_attr WHERE name = NEW.z3950_attr_type;

  IF FOUND THEN
    RETURN NULL;
  END IF;

  RAISE EXCEPTION '% is not a valid Z39.50 attribute type', NEW.z3950_attr_type;

END;
$func$ LANGUAGE PLPGSQL STABLE;

COMMENT ON FUNCTION evergreen.z3950_attr_name_is_valid() IS $$
Used by a config.z3950_index_field_map constraint trigger
to verify z3950_attr_type maps.
$$;

CREATE CONSTRAINT TRIGGER valid_z3950_attr_type AFTER INSERT OR UPDATE ON config.z3950_index_field_map
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW WHEN (NEW.z3950_attr_type IS NOT NULL)
  EXECUTE PROCEDURE evergreen.z3950_attr_name_is_valid();

SELECT evergreen.upgrade_deps_block_check('0964', :eg_version);

INSERT INTO config.coded_value_map
    (id, ctype, code, opac_visible, value, search_label) VALUES
(712, 'search_format', 'electronic', FALSE,
    oils_i18n_gettext(712, 'Electronic', 'ccvm', 'value'),
    oils_i18n_gettext(712, 'Electronic', 'ccvm', 'search_label'));

INSERT INTO config.composite_attr_entry_definition
    (coded_value, definition) VALUES
(712, '[{"_attr":"item_form","_val":"s"},{"_attr":"item_form","_val":"o"}]');


SELECT evergreen.upgrade_deps_block_check('0965', :eg_version);

UPDATE action_trigger.event_definition SET template =
$$
[%- USE date -%]
[%- SET user = target.0.usr -%]
[%- SET lib = target.0.circ_lib -%]
[%- SET lib_addr = target.0.circ_lib.billing_address -%]
[%- SET hours = lib.hours_of_operation -%]
<div>
    <style> li { padding: 8px; margin 5px; }</style>
    <div>[% date.format %]</div>
    <div>[% lib.name %]</div>
    <div>[% lib_addr.street1 %] [% lib_addr.street2 %]</div>
    <div>[% lib_addr.city %], [% lib_addr.state %] [% lib_addr.post_code %]</div>
    <div>[% lib.phone %]</div>
    <br/>

    [% user.family_name %], [% user.first_given_name %]
    <ol>
    [% FOR circ IN target %]
        [%-
            SET idx = loop.count - 1;
            SET udata =  user_data.$idx
        -%]
        <li>
            <div>[% helpers.get_copy_bib_basics(circ.target_copy.id).title %]</div>
            <div>Barcode: [% circ.target_copy.barcode %]</div>
            [% IF user_data.renewal_failure %]
                <div style='color:red;'>Renewal Failed</div>
            [% ELSE %]
                <div>Due Date: [% date.format(helpers.format_date(circ.due_date), '%Y-%m-%d') %]</div>
            [% END %]
        </li>
    [% END %]
    </ol>
    
    <div>
        Library Hours
        [%- BLOCK format_time; date.format(time _ ' 1/1/1000', format='%I:%M %p'); END -%]
        <div>
            Monday 
            [% PROCESS format_time time = hours.dow_0_open %] 
            [% PROCESS format_time time = hours.dow_0_close %] 
        </div>
        <div>
            Tuesday 
            [% PROCESS format_time time = hours.dow_1_open %] 
            [% PROCESS format_time time = hours.dow_1_close %] 
        </div>
        <div>
            Wednesday 
            [% PROCESS format_time time = hours.dow_2_open %] 
            [% PROCESS format_time time = hours.dow_2_close %] 
        </div>
        <div>
            Thursday
            [% PROCESS format_time time = hours.dow_3_open %] 
            [% PROCESS format_time time = hours.dow_3_close %] 
        </div>
        <div>
            Friday
            [% PROCESS format_time time = hours.dow_4_open %] 
            [% PROCESS format_time time = hours.dow_4_close %] 
        </div>
        <div>
            Saturday
            [% PROCESS format_time time = hours.dow_5_open %] 
            [% PROCESS format_time time = hours.dow_5_close %] 
        </div>
        <div>
            Sunday 
            [% PROCESS format_time time = hours.dow_6_open %] 
            [% PROCESS format_time time = hours.dow_6_close %] 
        </div>
    </div>
</div>
$$
WHERE id = 10 AND template =
$$
[%- USE date -%]
[%- SET user = target.0.usr -%]
[%- SET lib = target.0.circ_lib -%]
[%- SET lib_addr = target.0.circ_lib.billing_address -%]
[%- SET hours = lib.hours_of_operation -%]
<div>
    <style> li { padding: 8px; margin 5px; }</style>
    <div>[% date.format %]</div>
    <div>[% lib.name %]</div>
    <div>[% lib_addr.street1 %] [% lib_addr.street2 %]</div>
    <div>[% lib_addr.city %], [% lib_addr.state %] [% lb_addr.post_code %]</div>
    <div>[% lib.phone %]</div>
    <br/>

    [% user.family_name %], [% user.first_given_name %]
    <ol>
    [% FOR circ IN target %]
        [%-
            SET idx = loop.count - 1;
            SET udata =  user_data.$idx
        -%]
        <li>
            <div>[% helpers.get_copy_bib_basics(circ.target_copy.id).title %]</div>
            <div>Barcode: [% circ.target_copy.barcode %]</div>
            [% IF user_data.renewal_failure %]
                <div style='color:red;'>Renewal Failed</div>
            [% ELSE %]
                <div>Due Date: [% date.format(helpers.format_date(circ.due_date), '%Y-%m-%d') %]</div>
            [% END %]
        </li>
    [% END %]
    </ol>
    
    <div>
        Library Hours
        [%- BLOCK format_time; date.format(time _ ' 1/1/1000', format='%I:%M %p'); END -%]
        <div>
            Monday 
            [% PROCESS format_time time = hours.dow_0_open %] 
            [% PROCESS format_time time = hours.dow_0_close %] 
        </div>
        <div>
            Tuesday 
            [% PROCESS format_time time = hours.dow_1_open %] 
            [% PROCESS format_time time = hours.dow_1_close %] 
        </div>
        <div>
            Wednesday 
            [% PROCESS format_time time = hours.dow_2_open %] 
            [% PROCESS format_time time = hours.dow_2_close %] 
        </div>
        <div>
            Thursday
            [% PROCESS format_time time = hours.dow_3_open %] 
            [% PROCESS format_time time = hours.dow_3_close %] 
        </div>
        <div>
            Friday
            [% PROCESS format_time time = hours.dow_4_open %] 
            [% PROCESS format_time time = hours.dow_4_close %] 
        </div>
        <div>
            Saturday
            [% PROCESS format_time time = hours.dow_5_open %] 
            [% PROCESS format_time time = hours.dow_5_close %] 
        </div>
        <div>
            Sunday 
            [% PROCESS format_time time = hours.dow_6_open %] 
            [% PROCESS format_time time = hours.dow_6_close %] 
        </div>
    </div>
</div>
$$;

SELECT evergreen.upgrade_deps_block_check('0966', :eg_version); -- miker/jpringle/gmcharlt

-- Allow NULL post-normalization sorters
CREATE OR REPLACE FUNCTION metabib.reingest_record_attributes (rid BIGINT, pattr_list TEXT[] DEFAULT NULL, prmarc TEXT DEFAULT NULL, rdeleted BOOL DEFAULT TRUE) RETURNS VOID AS $func$
DECLARE
    transformed_xml TEXT;
    rmarc           TEXT := prmarc;
    tmp_val         TEXT;
    prev_xfrm       TEXT;
    normalizer      RECORD;
    xfrm            config.xml_transform%ROWTYPE;
    attr_vector     INT[] := '{}'::INT[];
    attr_vector_tmp INT[];
    attr_list       TEXT[] := pattr_list;
    attr_value      TEXT[];
    norm_attr_value TEXT[];
    tmp_xml         TEXT;
    attr_def        config.record_attr_definition%ROWTYPE;
    ccvm_row        config.coded_value_map%ROWTYPE;
BEGIN

    IF attr_list IS NULL OR rdeleted THEN -- need to do the full dance on INSERT or undelete
        SELECT ARRAY_AGG(name) INTO attr_list FROM config.record_attr_definition;
    END IF;

    IF rmarc IS NULL THEN
        SELECT marc INTO rmarc FROM biblio.record_entry WHERE id = rid;
    END IF;

    FOR attr_def IN SELECT * FROM config.record_attr_definition WHERE NOT composite AND name = ANY( attr_list ) ORDER BY format LOOP

        attr_value := '{}'::TEXT[];
        norm_attr_value := '{}'::TEXT[];
        attr_vector_tmp := '{}'::INT[];

        SELECT * INTO ccvm_row FROM config.coded_value_map c WHERE c.ctype = attr_def.name LIMIT 1; 

        -- tag+sf attrs only support SVF
        IF attr_def.tag IS NOT NULL THEN -- tag (and optional subfield list) selection
            SELECT  ARRAY[ARRAY_TO_STRING(ARRAY_AGG(value), COALESCE(attr_def.joiner,' '))] INTO attr_value
              FROM  (SELECT * FROM metabib.full_rec ORDER BY tag, subfield) AS x
              WHERE record = rid
                    AND tag LIKE attr_def.tag
                    AND CASE
                        WHEN attr_def.sf_list IS NOT NULL 
                            THEN POSITION(subfield IN attr_def.sf_list) > 0
                        ELSE TRUE
                    END
              GROUP BY tag
              ORDER BY tag
              LIMIT 1;

        ELSIF attr_def.fixed_field IS NOT NULL THEN -- a named fixed field, see config.marc21_ff_pos_map.fixed_field
            attr_value := vandelay.marc21_extract_fixed_field_list(rmarc, attr_def.fixed_field);

            IF NOT attr_def.multi THEN
                attr_value := ARRAY[attr_value[1]];
            END IF;

        ELSIF attr_def.xpath IS NOT NULL THEN -- and xpath expression

            SELECT INTO xfrm * FROM config.xml_transform WHERE name = attr_def.format;
        
            -- See if we can skip the XSLT ... it's expensive
            IF prev_xfrm IS NULL OR prev_xfrm <> xfrm.name THEN
                -- Can't skip the transform
                IF xfrm.xslt <> '---' THEN
                    transformed_xml := oils_xslt_process(rmarc,xfrm.xslt);
                ELSE
                    transformed_xml := rmarc;
                END IF;
    
                prev_xfrm := xfrm.name;
            END IF;

            IF xfrm.name IS NULL THEN
                -- just grab the marcxml (empty) transform
                SELECT INTO xfrm * FROM config.xml_transform WHERE xslt = '---' LIMIT 1;
                prev_xfrm := xfrm.name;
            END IF;

            FOR tmp_xml IN SELECT UNNEST(oils_xpath(attr_def.xpath, transformed_xml, ARRAY[ARRAY[xfrm.prefix, xfrm.namespace_uri]])) LOOP
                tmp_val := oils_xpath_string(
                                '//*',
                                tmp_xml,
                                COALESCE(attr_def.joiner,' '),
                                ARRAY[ARRAY[xfrm.prefix, xfrm.namespace_uri]]
                            );
                IF tmp_val IS NOT NULL AND BTRIM(tmp_val) <> '' THEN
                    attr_value := attr_value || tmp_val;
                    EXIT WHEN NOT attr_def.multi;
                END IF;
            END LOOP;

        ELSIF attr_def.phys_char_sf IS NOT NULL THEN -- a named Physical Characteristic, see config.marc21_physical_characteristic_*_map
            SELECT  ARRAY_AGG(m.value) INTO attr_value
              FROM  vandelay.marc21_physical_characteristics(rmarc) v
                    LEFT JOIN config.marc21_physical_characteristic_value_map m ON (m.id = v.value)
              WHERE v.subfield = attr_def.phys_char_sf AND (m.value IS NOT NULL AND BTRIM(m.value) <> '')
                    AND ( ccvm_row.id IS NULL OR ( ccvm_row.id IS NOT NULL AND v.id IS NOT NULL) );

            IF NOT attr_def.multi THEN
                attr_value := ARRAY[attr_value[1]];
            END IF;

        END IF;

                -- apply index normalizers to attr_value
        FOR tmp_val IN SELECT value FROM UNNEST(attr_value) x(value) LOOP
            FOR normalizer IN
                SELECT  n.func AS func,
                        n.param_count AS param_count,
                        m.params AS params
                  FROM  config.index_normalizer n
                        JOIN config.record_attr_index_norm_map m ON (m.norm = n.id)
                  WHERE attr = attr_def.name
                  ORDER BY m.pos LOOP
                    EXECUTE 'SELECT ' || normalizer.func || '(' ||
                    COALESCE( quote_literal( tmp_val ), 'NULL' ) ||
                        CASE
                            WHEN normalizer.param_count > 0
                                THEN ',' || REPLACE(REPLACE(BTRIM(normalizer.params,'[]'),E'\'',E'\\\''),E'"',E'\'')
                                ELSE ''
                            END ||
                    ')' INTO tmp_val;

            END LOOP;
            IF tmp_val IS NOT NULL AND tmp_val <> '' THEN
                -- note that a string that contains only blanks
                -- is a valid value for some attributes
                norm_attr_value := norm_attr_value || tmp_val;
            END IF;
        END LOOP;
        
        IF attr_def.filter THEN
            -- Create unknown uncontrolled values and find the IDs of the values
            IF ccvm_row.id IS NULL THEN
                FOR tmp_val IN SELECT value FROM UNNEST(norm_attr_value) x(value) LOOP
                    IF tmp_val IS NOT NULL AND BTRIM(tmp_val) <> '' THEN
                        BEGIN -- use subtransaction to isolate unique constraint violations
                            INSERT INTO metabib.uncontrolled_record_attr_value ( attr, value ) VALUES ( attr_def.name, tmp_val );
                        EXCEPTION WHEN unique_violation THEN END;
                    END IF;
                END LOOP;

                SELECT ARRAY_AGG(id) INTO attr_vector_tmp FROM metabib.uncontrolled_record_attr_value WHERE attr = attr_def.name AND value = ANY( norm_attr_value );
            ELSE
                SELECT ARRAY_AGG(id) INTO attr_vector_tmp FROM config.coded_value_map WHERE ctype = attr_def.name AND code = ANY( norm_attr_value );
            END IF;

            -- Add the new value to the vector
            attr_vector := attr_vector || attr_vector_tmp;
        END IF;

        IF attr_def.sorter THEN
            DELETE FROM metabib.record_sorter WHERE source = rid AND attr = attr_def.name;
            IF norm_attr_value[1] IS NOT NULL THEN
                INSERT INTO metabib.record_sorter (source, attr, value) VALUES (rid, attr_def.name, norm_attr_value[1]);
            END IF;
        END IF;

    END LOOP;

/* We may need to rewrite the vlist to contain
   the intersection of new values for requested
   attrs and old values for ignored attrs. To
   do this, we take the old attr vlist and
   subtract any values that are valid for the
   requested attrs, and then add back the new
   set of attr values. */

    IF ARRAY_LENGTH(pattr_list, 1) > 0 THEN 
        SELECT vlist INTO attr_vector_tmp FROM metabib.record_attr_vector_list WHERE source = rid;
        SELECT attr_vector_tmp - ARRAY_AGG(id::INT) INTO attr_vector_tmp FROM metabib.full_attr_id_map WHERE attr = ANY (pattr_list);
        attr_vector := attr_vector || attr_vector_tmp;
    END IF;

    -- On to composite attributes, now that the record attrs have been pulled.  Processed in name order, so later composite
    -- attributes can depend on earlier ones.
    PERFORM metabib.compile_composite_attr_cache_init();
    FOR attr_def IN SELECT * FROM config.record_attr_definition WHERE composite AND name = ANY( attr_list ) ORDER BY name LOOP

        FOR ccvm_row IN SELECT * FROM config.coded_value_map c WHERE c.ctype = attr_def.name ORDER BY value LOOP

            tmp_val := metabib.compile_composite_attr( ccvm_row.id );
            CONTINUE WHEN tmp_val IS NULL OR tmp_val = ''; -- nothing to do

            IF attr_def.filter THEN
                IF attr_vector @@ tmp_val::query_int THEN
                    attr_vector = attr_vector + intset(ccvm_row.id);
                    EXIT WHEN NOT attr_def.multi;
                END IF;
            END IF;

            IF attr_def.sorter THEN
                IF attr_vector @@ tmp_val THEN
                    DELETE FROM metabib.record_sorter WHERE source = rid AND attr = attr_def.name;
                    INSERT INTO metabib.record_sorter (source, attr, value) VALUES (rid, attr_def.name, ccvm_row.code);
                END IF;
            END IF;

        END LOOP;

    END LOOP;

    IF ARRAY_LENGTH(attr_vector, 1) > 0 THEN
        IF rdeleted THEN -- initial insert OR revivication
            DELETE FROM metabib.record_attr_vector_list WHERE source = rid;
            INSERT INTO metabib.record_attr_vector_list (source, vlist) VALUES (rid, attr_vector);
        ELSE
            UPDATE metabib.record_attr_vector_list SET vlist = attr_vector WHERE source = rid;
        END IF;
    END IF;

END;

$func$ LANGUAGE PLPGSQL;

-- Correct SER and COM records, add most other subfields and make them usable as CCVMs

SELECT evergreen.upgrade_deps_block_check('0967', :eg_version);

-- Fix SER
DELETE FROM config.marc21_ff_pos_map WHERE fixed_field = 'Audn' AND rec_type = 'SER';


-- Map Fields to Record Types
-- Form was already defined but missing from COM
INSERT INTO config.marc21_ff_pos_map (fixed_field, tag, rec_type,start_pos, length, default_val) VALUES
    ('Form', '006', 'COM', 6, 1, ' '),
    ('Form', '008', 'COM', 23, 1, ' '),

    ('Relf', '006', 'MAP', 1, 4, '    '),
    ('Relf', '008', 'MAP', 18, 4, '    '),
    ('Proj', '006', 'MAP', 5, 2, '  '),
    ('Proj', '008', 'MAP', 22, 2, '  '),
    ('CrTp', '006', 'MAP', 8, 1, 'a'),
    ('CrTp', '008', 'MAP', 25, 1, 'a'),
    ('SpFm', '006', 'MAP', 16, 2, '  '),
    ('SpFm', '008', 'MAP', 33, 2, '  '),
    ('Relf1', '006', 'MAP', 1, 1, ' '),
    ('Relf1', '008', 'MAP', 18, 1, ' '),
    ('Relf2', '006', 'MAP', 2, 1, ' '),
    ('Relf2', '008', 'MAP', 19, 1, ' '),
    ('Relf3', '006', 'MAP', 3, 1, ' '),
    ('Relf3', '008', 'MAP', 20, 1, ' '),
    ('Relf4', '006', 'MAP', 4, 1, ' '),
    ('Relf4', '008', 'MAP', 21, 1, ' '),
    ('SpFm1', '006', 'MAP', 16, 1, ' '),
    ('SpFm1', '008', 'MAP', 33, 1, ' '),
    ('SpFm2', '006', 'MAP', 17, 1, ' '),
    ('SpFm2', '008', 'MAP', 34, 1, ' '),

    ('Comp', '006', 'REC', 1, 2, 'uu'),
    ('Comp', '008', 'REC', 18, 2, 'uu'),
    ('FMus', '006', 'REC', 3, 1, 'n'),
    ('FMus', '008', 'REC', 20, 1, 'n'),
    ('Part', '006', 'REC', 4, 1, 'n'),
    ('Part', '008', 'REC', 21, 1, 'n'),
    ('AccM', '006', 'REC', 7, 6, '      '),
    ('AccM', '008', 'REC', 24, 6, '      '),
    ('LTxt', '006', 'REC', 13, 2, '  '),
    ('LTxt', '008', 'REC', 30, 2, '  '),
    ('TrAr', '006', 'REC', 16, 1, 'n'),
    ('TrAr', '008', 'REC', 33, 1, 'n'),
    ('AccM1', '006', 'REC', 7, 1, ' '),
    ('AccM1', '008', 'REC', 24, 1, ' '),
    ('AccM2', '006', 'REC', 8, 1, ' '),
    ('AccM2', '008', 'REC', 25, 1, ' '),
    ('AccM3', '006', 'REC', 9, 1, ' '),
    ('AccM3', '008', 'REC', 26, 1, ' '),
    ('AccM4', '006', 'REC', 10, 1, ' '),
    ('AccM4', '008', 'REC', 27, 1, ' '),
    ('AccM5', '006', 'REC', 11, 1, ' '),
    ('AccM5', '008', 'REC', 28, 1, ' '),
    ('AccM6', '006', 'REC', 12, 1, ' '),
    ('AccM6', '008', 'REC', 29, 1, ' '),
    ('LTxt1', '006', 'REC', 13, 1, ' '),
    ('LTxt1', '008', 'REC', 30, 1, ' '),
    ('LTxt2', '006', 'REC', 14, 1, ' '),
    ('LTxt2', '008', 'REC', 31, 1, ' '),

    ('Comp', '006', 'SCO', 1, 2, 'uu'),
    ('Comp', '008', 'SCO', 18, 2, 'uu'),
    ('FMus', '006', 'SCO', 3, 1, 'u'),
    ('FMus', '008', 'SCO', 20, 1, 'u'),
    ('Part', '006', 'SCO', 4, 1, ' '),
    ('Part', '008', 'SCO', 21, 1, ' '),
    ('AccM', '006', 'SCO', 7, 6, '      '),
    ('AccM', '008', 'SCO', 24, 6, '      '),
    ('LTxt', '006', 'SCO', 13, 2, 'n '),
    ('LTxt', '008', 'SCO', 30, 2, 'n '),
    ('TrAr', '006', 'SCO', 16, 1, ' '),
    ('TrAr', '008', 'SCO', 33, 1, ' '),
    ('AccM1', '006', 'SCO', 7, 1, ' '),
    ('AccM1', '008', 'SCO', 24, 1, ' '),
    ('AccM2', '006', 'SCO', 8, 1, ' '),
    ('AccM2', '008', 'SCO', 25, 1, ' '),
    ('AccM3', '006', 'SCO', 9, 1, ' '),
    ('AccM3', '008', 'SCO', 26, 1, ' '),
    ('AccM4', '006', 'SCO', 10, 1, ' '),
    ('AccM4', '008', 'SCO', 27, 1, ' '),
    ('AccM5', '006', 'SCO', 11, 1, ' '),
    ('AccM5', '008', 'SCO', 28, 1, ' '),
    ('AccM6', '006', 'SCO', 12, 1, ' '),
    ('AccM6', '008', 'SCO', 29, 1, ' '),
    ('LTxt1', '006', 'SCO', 13, 1, 'n'),
    ('LTxt1', '008', 'SCO', 30, 1, 'n'),
    ('LTxt2', '006', 'SCO', 14, 1, 'n'),
    ('LTxt2', '008', 'SCO', 31, 1, 'n'),

    ('SrTp', '006', 'SER', 4, 1, ' '),
    ('SrTp', '008', 'SER', 21, 1, ' '),
    ('Orig', '006', 'SER', 5, 1, ' '),
    ('Orig', '008', 'SER', 22, 1, ' '),
    ('EntW', '006', 'SER', 7, 1, ' '),
    ('EntW', '008', 'SER', 24, 1, ' '),

    ('Time', '006', 'VIS', 1, 3, '   '),
    ('Time', '008', 'VIS', 18, 3, '   '),
    ('Tech', '006', 'VIS', 17, 1, 'n'),
    ('Tech', '008', 'VIS', 34, 1, 'n'),
	
	('Ills1', '006', 'BKS', 1, 1, ' '),
    ('Ills1', '008', 'BKS', 18, 1, ' '),
    ('Ills2', '006', 'BKS', 2, 1, ' '),
    ('Ills2', '008', 'BKS', 19, 1, ' '),
    ('Ills3', '006', 'BKS', 3, 1, ' '),
    ('Ills3', '008', 'BKS', 20, 1, ' '),
    ('Ills4', '006', 'BKS', 4, 1, ' '),
    ('Ills4', '008', 'BKS', 21, 1, ' '),
    ('Cont1', '006', 'BKS', 7, 1, ' '),
    ('Cont1', '008', 'BKS', 24, 1, ' '),
    ('Cont2', '006', 'BKS', 8, 1, ' '),
    ('Cont2', '008', 'BKS', 25, 1, ' '),
    ('Cont3', '006', 'BKS', 9, 1, ' '),
    ('Cont3', '008', 'BKS', 26, 1, ' '),
    ('Cont4', '006', 'BKS', 10, 1, ' '),
    ('Cont4', '008', 'BKS', 27, 1, ' '),

    ('Cont1', '006', 'SER', 8, 1, ' '),
    ('Cont1', '008', 'SER', 25, 1, ' '),
    ('Cont2', '006', 'SER', 9, 1, ' '),
    ('Cont2', '008', 'SER', 26, 1, ' '),
    ('Cont3', '006', 'SER', 10, 1, ' '),
    ('Cont3', '008', 'SER', 27, 1, ' ');


-- Add record_attr_definitions
-- The xxx1,2,etc. are for multi-position single character code fields.
INSERT INTO config.record_attr_definition (name,label,fixed_field) VALUES
    ('accm','AccM','AccM'),
    ('comp','Comp','Comp'),
    ('crtp','CrTp','CrTp'),
    ('entw','EntW','EntW'),
    ('cont','Cont','Cont'),
    ('fmus','FMus','FMus'),
    ('ltxt','LTxt','LTxt'),
    ('orig','Orig','Orig'),
    ('part','Part','Part'),
    ('proj','Proj','Proj'),
    ('relf','Relf','Relf'),
    ('spfm','SpFm','SpFm'),
    ('srtp','SrTp','SrTp'),
    ('tech','Tech','Tech'),
    ('trar','TrAr','TrAr'),
    ('accm1','AccM(1)','AccM1'),
    ('accm2','AccM(2)','AccM2'),
    ('accm3','AccM(3)','AccM3'),
    ('accm4','AccM(4)','AccM4'),
    ('accm5','AccM(5)','AccM5'),
    ('accm6','AccM(6)','AccM6'),
    ('cont1','Cont(1)','Cont1'),
    ('cont2','Cont(2)','Cont2'),
    ('cont3','Cont(3)','Cont3'),
    ('cont4','Cont(4)','Cont4'),
    ('ills1','Ills(1)','Ills1'),
    ('ills2','Ills(2)','Ills2'),
    ('ills3','Ills(3)','Ills3'),
    ('ills4','Ills(4)','Ills4'),
    ('ltxt1','LTxt(1)','LTxt1'),
    ('ltxt2','LTxt(2)','LTxt2'),
    ('relf1','Relf(1)','Relf1'),
    ('relf2','Relf(2)','Relf2'),
    ('relf3','Relf(3)','Relf3'),
    ('relf4','Relf(4)','Relf4'),
    ('spfm1','SpFm(1)','SpFm1'),
    ('spfm2','SpFm(2)','SpFm2');

UPDATE config.record_attr_definition SET composite = TRUE WHERE name IN ('accm', 'cont', 'ills', 'ltxt', 'relf', 'spfm');

-- "Next" id for stock config.coded_value_map is 634 as of 7/16/15, but there's an incoming patch that takes 634-711
INSERT INTO config.coded_value_map (id, ctype, code, value) VALUES
    (1735, 'accm', ' ', 		oils_i18n_gettext('1735', 'No accompanying matter', 'ccvm', 'value')),
    (713, 'accm', 'a', 			oils_i18n_gettext('713', 'Discography', 'ccvm', 'value')),
    (714, 'accm', 'b', 			oils_i18n_gettext('714', 'Bibliography', 'ccvm', 'value')),
    (715, 'accm', 'c', 			oils_i18n_gettext('715', 'Thematic index', 'ccvm', 'value')),
    (716, 'accm', 'd', 			oils_i18n_gettext('716', 'Libretto or text', 'ccvm', 'value')),
    (717, 'accm', 'e', 			oils_i18n_gettext('717', 'Biography of composer or author', 'ccvm', 'value')),
    (718, 'accm', 'f', 			oils_i18n_gettext('718', 'Biography or performer or history of ensemble', 'ccvm', 'value')),
    (719, 'accm', 'g', 			oils_i18n_gettext('719', 'Technical and/or historical information on instruments', 'ccvm', 'value')),
    (720, 'accm', 'h', 			oils_i18n_gettext('720', 'Technical information on music', 'ccvm', 'value')),
    (721, 'accm', 'i', 			oils_i18n_gettext('721', 'Historical information', 'ccvm', 'value')),
    (722, 'accm', 'k', 			oils_i18n_gettext('722', 'Ethnological information', 'ccvm', 'value')),
    (723, 'accm', 'r', 			oils_i18n_gettext('723', 'Instructional materials', 'ccvm', 'value')),
    (724, 'accm', 's', 			oils_i18n_gettext('724', 'Music', 'ccvm', 'value')),
    (725, 'accm', 'z', 			oils_i18n_gettext('725', 'Other accompanying matter', 'ccvm', 'value')),
	
    (726, 'comp', '  ', 		oils_i18n_gettext('726', 'No information supplied', 'ccvm', 'value')),
    (727, 'comp', 'an', 		oils_i18n_gettext('727', 'Anthems', 'ccvm', 'value')),
    (728, 'comp', 'bd', 		oils_i18n_gettext('728', 'Ballads', 'ccvm', 'value')),
    (729, 'comp', 'bt', 		oils_i18n_gettext('729', 'Ballets', 'ccvm', 'value')),
    (730, 'comp', 'bg', 		oils_i18n_gettext('730', 'Bluegrass music', 'ccvm', 'value')),
    (731, 'comp', 'bl', 		oils_i18n_gettext('731', 'Blues', 'ccvm', 'value')),
    (732, 'comp', 'cn', 		oils_i18n_gettext('732', 'Canons and rounds', 'ccvm', 'value')),
    (733, 'comp', 'ct', 		oils_i18n_gettext('733', 'Cantatas', 'ccvm', 'value')),
    (734, 'comp', 'cz', 		oils_i18n_gettext('734', 'Canzonas', 'ccvm', 'value')),
    (735, 'comp', 'cr', 		oils_i18n_gettext('735', 'Carols', 'ccvm', 'value')),
    (736, 'comp', 'ca', 		oils_i18n_gettext('736', 'Chaconnes', 'ccvm', 'value')),
    (737, 'comp', 'cs', 		oils_i18n_gettext('737', 'Chance compositions', 'ccvm', 'value')),
    (738, 'comp', 'cp', 		oils_i18n_gettext('738', 'Chansons, Polyphonic', 'ccvm', 'value')),
    (739, 'comp', 'cc', 		oils_i18n_gettext('739', 'Chant, Christian', 'ccvm', 'value')),
    (740, 'comp', 'cb', 		oils_i18n_gettext('740', 'Chants, other', 'ccvm', 'value')),
    (741, 'comp', 'cl', 		oils_i18n_gettext('741', 'Chorale preludes', 'ccvm', 'value')),
    (742, 'comp', 'ch', 		oils_i18n_gettext('742', 'Chorales', 'ccvm', 'value')),
    (743, 'comp', 'cg', 		oils_i18n_gettext('743', 'Concerti grossi', 'ccvm', 'value')),
    (744, 'comp', 'co', 		oils_i18n_gettext('744', 'Concertos', 'ccvm', 'value')),
    (745, 'comp', 'cy', 		oils_i18n_gettext('745', 'Country music', 'ccvm', 'value')),
    (746, 'comp', 'df', 		oils_i18n_gettext('746', 'Dance forms', 'ccvm', 'value')),
    (747, 'comp', 'dv', 		oils_i18n_gettext('747', 'Divertimentos, serenades, cassations, divertissements, and notturni', 'ccvm', 'value')),
    (748, 'comp', 'ft', 		oils_i18n_gettext('748', 'Fantasias', 'ccvm', 'value')),
    (749, 'comp', 'fl', 		oils_i18n_gettext('749', 'Flamenco', 'ccvm', 'value')),
    (750, 'comp', 'fm', 		oils_i18n_gettext('750', 'Folk music', 'ccvm', 'value')),
    (751, 'comp', 'fg', 		oils_i18n_gettext('751', 'Fugues', 'ccvm', 'value')),
    (752, 'comp', 'gm', 		oils_i18n_gettext('752', 'Gospel music', 'ccvm', 'value')),
    (753, 'comp', 'hy', 		oils_i18n_gettext('753', 'Hymns', 'ccvm', 'value')),
    (754, 'comp', 'jz', 		oils_i18n_gettext('754', 'Jazz', 'ccvm', 'value')),
    (755, 'comp', 'md', 		oils_i18n_gettext('755', 'Madrigals', 'ccvm', 'value')),
    (756, 'comp', 'mr', 		oils_i18n_gettext('756', 'Marches', 'ccvm', 'value')),
    (757, 'comp', 'ms', 		oils_i18n_gettext('757', 'Masses', 'ccvm', 'value')),
    (758, 'comp', 'mz', 		oils_i18n_gettext('758', 'Mazurkas', 'ccvm', 'value')),
    (759, 'comp', 'mi', 		oils_i18n_gettext('759', 'Minuets', 'ccvm', 'value')),
    (760, 'comp', 'mo', 		oils_i18n_gettext('760', 'Motets', 'ccvm', 'value')),
    (761, 'comp', 'mp', 		oils_i18n_gettext('761', 'Motion picture music', 'ccvm', 'value')),
    (762, 'comp', 'mu', 		oils_i18n_gettext('762', 'Multiple forms', 'ccvm', 'value')),
    (763, 'comp', 'mc', 		oils_i18n_gettext('763', 'Musical reviews and comedies', 'ccvm', 'value')),
    (764, 'comp', 'nc', 		oils_i18n_gettext('764', 'Nocturnes', 'ccvm', 'value')),
    (765, 'comp', 'nn', 		oils_i18n_gettext('765', 'Not applicable', 'ccvm', 'value')),
    (766, 'comp', 'op', 		oils_i18n_gettext('766', 'Operas', 'ccvm', 'value')),
    (767, 'comp', 'or', 		oils_i18n_gettext('767', 'Oratorios', 'ccvm', 'value')),
    (768, 'comp', 'ov', 		oils_i18n_gettext('768', 'Overtures', 'ccvm', 'value')),
    (769, 'comp', 'pt', 		oils_i18n_gettext('769', 'Part-songs', 'ccvm', 'value')),
    (770, 'comp', 'ps', 		oils_i18n_gettext('770', 'Passacaglias', 'ccvm', 'value')),
    (771, 'comp', 'pm', 		oils_i18n_gettext('771', 'Passion music', 'ccvm', 'value')),
    (772, 'comp', 'pv', 		oils_i18n_gettext('772', 'Pavans', 'ccvm', 'value')),
    (773, 'comp', 'po', 		oils_i18n_gettext('773', 'Polonaises', 'ccvm', 'value')),
    (774, 'comp', 'pp', 		oils_i18n_gettext('774', 'Popular music', 'ccvm', 'value')),
    (775, 'comp', 'pr', 		oils_i18n_gettext('775', 'Preludes', 'ccvm', 'value')),
    (776, 'comp', 'pg', 		oils_i18n_gettext('776', 'Program music', 'ccvm', 'value')),
    (777, 'comp', 'rg', 		oils_i18n_gettext('777', 'Ragtime music', 'ccvm', 'value')),
    (778, 'comp', 'rq', 		oils_i18n_gettext('778', 'Requiems', 'ccvm', 'value')),
    (779, 'comp', 'rp', 		oils_i18n_gettext('779', 'Rhapsodies', 'ccvm', 'value')),
    (780, 'comp', 'ri', 		oils_i18n_gettext('780', 'Ricercars', 'ccvm', 'value')),
    (781, 'comp', 'rc', 		oils_i18n_gettext('781', 'Rock music', 'ccvm', 'value')),
    (782, 'comp', 'rd', 		oils_i18n_gettext('782', 'Rondos', 'ccvm', 'value')),
    (783, 'comp', 'sn', 		oils_i18n_gettext('783', 'Sonatas', 'ccvm', 'value')),
    (784, 'comp', 'sg', 		oils_i18n_gettext('784', 'Songs', 'ccvm', 'value')),
    (785, 'comp', 'sd', 		oils_i18n_gettext('785', 'Square dance music', 'ccvm', 'value')),
    (786, 'comp', 'st', 		oils_i18n_gettext('786', 'Studies and exercises', 'ccvm', 'value')),
    (787, 'comp', 'su', 		oils_i18n_gettext('787', 'Suites', 'ccvm', 'value')),
    (788, 'comp', 'sp', 		oils_i18n_gettext('788', 'Symphonic poems', 'ccvm', 'value')),
    (789, 'comp', 'sy', 		oils_i18n_gettext('789', 'Symphonies', 'ccvm', 'value')),
    (790, 'comp', 'tl', 		oils_i18n_gettext('790', 'Teatro lirico', 'ccvm', 'value')),
    (791, 'comp', 'tc', 		oils_i18n_gettext('791', 'Toccatas', 'ccvm', 'value')),
    (792, 'comp', 'ts', 		oils_i18n_gettext('792', 'Trio-sonatas', 'ccvm', 'value')),
    (793, 'comp', 'uu', 		oils_i18n_gettext('793', 'Unknown', 'ccvm', 'value')),
    (794, 'comp', 'vi', 		oils_i18n_gettext('794', 'Villancicos', 'ccvm', 'value')),
    (795, 'comp', 'vr', 		oils_i18n_gettext('795', 'Variations', 'ccvm', 'value')),
    (796, 'comp', 'wz', 		oils_i18n_gettext('796', 'Waltzes', 'ccvm', 'value')),
    (797, 'comp', 'za', 		oils_i18n_gettext('797', 'Zarzuelas', 'ccvm', 'value')),
    (798, 'comp', 'zz', 		oils_i18n_gettext('798', 'Other forms', 'ccvm', 'value')),
	
    (799, 'crtp', 'a', 			oils_i18n_gettext('799', 'Single map', 'ccvm', 'value')),
    (800, 'crtp', 'b', 			oils_i18n_gettext('800', 'Map series', 'ccvm', 'value')),
    (801, 'crtp', 'c', 			oils_i18n_gettext('801', 'Map serial', 'ccvm', 'value')),
    (802, 'crtp', 'd', 			oils_i18n_gettext('802', 'Globe', 'ccvm', 'value')),
    (803, 'crtp', 'e', 			oils_i18n_gettext('803', 'Atlas', 'ccvm', 'value')),
    (804, 'crtp', 'f', 			oils_i18n_gettext('804', 'Separate supplement to another work', 'ccvm', 'value')),
    (805, 'crtp', 'g', 			oils_i18n_gettext('805', 'Bound as part of another work', 'ccvm', 'value')),
    (806, 'crtp', 'u', 			oils_i18n_gettext('806', 'Unknown', 'ccvm', 'value')),
    (807, 'crtp', 'z', 			oils_i18n_gettext('807', 'Other', 'ccvm', 'value')),
	
    (808, 'entw', ' ', 			oils_i18n_gettext('808', 'Not specified', 'ccvm', 'value')),
    (809, 'entw', 'a', 			oils_i18n_gettext('809', 'Abstracts/summaries', 'ccvm', 'value')),
    (810, 'entw', 'b', 			oils_i18n_gettext('810', 'Bibliographies', 'ccvm', 'value')),
    (811, 'entw', 'c', 			oils_i18n_gettext('811', 'Catalogs', 'ccvm', 'value')),
    (812, 'entw', 'd', 			oils_i18n_gettext('812', 'Dictionaries', 'ccvm', 'value')),
    (813, 'entw', 'e', 			oils_i18n_gettext('813', 'Encyclopedias', 'ccvm', 'value')),
    (814, 'entw', 'f', 			oils_i18n_gettext('814', 'Handbooks', 'ccvm', 'value')),
    (815, 'entw', 'g', 			oils_i18n_gettext('815', 'Legal articles', 'ccvm', 'value')),
    (816, 'entw', 'h', 			oils_i18n_gettext('816', 'Biography', 'ccvm', 'value')),
    (817, 'entw', 'i', 			oils_i18n_gettext('817', 'Indexes', 'ccvm', 'value')),
    (818, 'entw', 'k', 			oils_i18n_gettext('818', 'Discographies', 'ccvm', 'value')),
    (819, 'entw', 'l', 			oils_i18n_gettext('819', 'Legislation', 'ccvm', 'value')),
    (820, 'entw', 'm', 			oils_i18n_gettext('820', 'Theses', 'ccvm', 'value')),
    (821, 'entw', 'n', 			oils_i18n_gettext('821', 'Surveys of the literature in a subject area', 'ccvm', 'value')),
    (822, 'entw', 'o', 			oils_i18n_gettext('822', 'Reviews', 'ccvm', 'value')),
    (823, 'entw', 'p', 			oils_i18n_gettext('823', 'Programmed texts', 'ccvm', 'value')),
    (824, 'entw', 'q', 			oils_i18n_gettext('824', 'Filmographies', 'ccvm', 'value')),
    (825, 'entw', 'r', 			oils_i18n_gettext('825', 'Directories', 'ccvm', 'value')),
    (826, 'entw', 's', 			oils_i18n_gettext('826', 'Statistics', 'ccvm', 'value')),
    (827, 'entw', 't', 			oils_i18n_gettext('827', 'Technical reports', 'ccvm', 'value')),
    (828, 'entw', 'u', 			oils_i18n_gettext('828', 'Standards/specifications', 'ccvm', 'value')),
    (829, 'entw', 'v', 			oils_i18n_gettext('829', 'Legal cases and case notes', 'ccvm', 'value')),
    (830, 'entw', 'w', 			oils_i18n_gettext('830', 'Law reports and digests', 'ccvm', 'value')),
    (831, 'entw', 'y', 			oils_i18n_gettext('831', 'Yearbooks', 'ccvm', 'value')),
    (832, 'entw', 'z', 			oils_i18n_gettext('832', 'Treaties', 'ccvm', 'value')),
    (833, 'entw', '5', 			oils_i18n_gettext('833', 'Calendars', 'ccvm', 'value')),
    (834, 'entw', '6', 			oils_i18n_gettext('834', 'Comics/graphic novels', 'ccvm', 'value')),
	
    (835, 'cont', ' ', 			oils_i18n_gettext('835', 'Not specified', 'ccvm', 'value')),
    (836, 'cont', 'a', 			oils_i18n_gettext('836', 'Abstracts/summaries', 'ccvm', 'value')),
    (837, 'cont', 'b', 			oils_i18n_gettext('837', 'Bibliographies', 'ccvm', 'value')),
    (838, 'cont', 'c', 			oils_i18n_gettext('838', 'Catalogs', 'ccvm', 'value')),
    (839, 'cont', 'd', 			oils_i18n_gettext('839', 'Dictionaries', 'ccvm', 'value')),
    (840, 'cont', 'e', 			oils_i18n_gettext('840', 'Encyclopedias', 'ccvm', 'value')),
    (841, 'cont', 'f', 			oils_i18n_gettext('841', 'Handbooks', 'ccvm', 'value')),
    (842, 'cont', 'g', 			oils_i18n_gettext('842', 'Legal articles', 'ccvm', 'value')),
    (843, 'cont', 'h', 			oils_i18n_gettext('843', 'Biography', 'ccvm', 'value')),
    (844, 'cont', 'i', 			oils_i18n_gettext('844', 'Indexes', 'ccvm', 'value')),
    (845, 'cont', 'j', 			oils_i18n_gettext('845', 'Patent document', 'ccvm', 'value')),
    (846, 'cont', 'k', 			oils_i18n_gettext('846', 'Discographies', 'ccvm', 'value')),
    (847, 'cont', 'l', 			oils_i18n_gettext('847', 'Legislation', 'ccvm', 'value')),
    (848, 'cont', 'm', 			oils_i18n_gettext('848', 'Theses', 'ccvm', 'value')),
    (849, 'cont', 'n', 			oils_i18n_gettext('849', 'Surveys of the literature in a subject area', 'ccvm', 'value')),
    (850, 'cont', 'o', 			oils_i18n_gettext('850', 'Reviews', 'ccvm', 'value')),
    (851, 'cont', 'p', 			oils_i18n_gettext('851', 'Programmed texts', 'ccvm', 'value')),
    (852, 'cont', 'q', 			oils_i18n_gettext('852', 'Filmographies', 'ccvm', 'value')),
    (853, 'cont', 'r', 			oils_i18n_gettext('853', 'Directories', 'ccvm', 'value')),
    (854, 'cont', 's', 			oils_i18n_gettext('854', 'Statistics', 'ccvm', 'value')),
    (855, 'cont', 't', 			oils_i18n_gettext('855', 'Technical reports', 'ccvm', 'value')),
    (856, 'cont', 'u', 			oils_i18n_gettext('856', 'Standards/specifications', 'ccvm', 'value')),
    (857, 'cont', 'v', 			oils_i18n_gettext('857', 'Legal cases and case notes', 'ccvm', 'value')),
    (858, 'cont', 'w', 			oils_i18n_gettext('858', 'Law reports and digests', 'ccvm', 'value')),
    (859, 'cont', 'x', 			oils_i18n_gettext('859', 'Other reports', 'ccvm', 'value')),
    (860, 'cont', 'y', 			oils_i18n_gettext('860', 'Yearbooks', 'ccvm', 'value')),
    (861, 'cont', 'z', 			oils_i18n_gettext('861', 'Treaties', 'ccvm', 'value')),
    (862, 'cont', '2', 			oils_i18n_gettext('862', 'Offprints', 'ccvm', 'value')),
    (863, 'cont', '5', 			oils_i18n_gettext('863', 'Calendars', 'ccvm', 'value')),
    (864, 'cont', '6', 			oils_i18n_gettext('864', 'Comics/graphic novels', 'ccvm', 'value')),
	
    (865, 'fmus', ' ', 			oils_i18n_gettext('865', 'Information not supplied', 'ccvm', 'value')),
    (866, 'fmus', 'a', 			oils_i18n_gettext('866', 'Full score', 'ccvm', 'value')),
    (867, 'fmus', 'b', 			oils_i18n_gettext('867', 'Full score, miniature or study size', 'ccvm', 'value')),
    (868, 'fmus', 'c', 			oils_i18n_gettext('868', 'Accompaniment reduced for keyboard', 'ccvm', 'value')),
    (869, 'fmus', 'd', 			oils_i18n_gettext('869', 'Voice score with accompaniment omitted', 'ccvm', 'value')),
    (870, 'fmus', 'e', 			oils_i18n_gettext('870', 'Condensed score or piano-conductor score', 'ccvm', 'value')),
    (871, 'fmus', 'g', 			oils_i18n_gettext('871', 'Close score', 'ccvm', 'value')),
    (872, 'fmus', 'h', 			oils_i18n_gettext('872', 'Chorus score', 'ccvm', 'value')),
    (873, 'fmus', 'i', 			oils_i18n_gettext('873', 'Condensed score', 'ccvm', 'value')),
    (874, 'fmus', 'j', 			oils_i18n_gettext('874', 'Performer-conductor part', 'ccvm', 'value')),
    (875, 'fmus', 'k', 			oils_i18n_gettext('875', 'Vocal score', 'ccvm', 'value')),
    (876, 'fmus', 'l', 			oils_i18n_gettext('876', 'Score', 'ccvm', 'value')),
    (877, 'fmus', 'm', 			oils_i18n_gettext('877', 'Multiple score formats', 'ccvm', 'value')),
    (878, 'fmus', 'n', 			oils_i18n_gettext('878', 'Not applicable', 'ccvm', 'value')),
    (879, 'fmus', 'u', 			oils_i18n_gettext('879', 'Unknown', 'ccvm', 'value')),
    (880, 'fmus', 'z', 			oils_i18n_gettext('880', 'Other', 'ccvm', 'value')),
	
    (881, 'ltxt', ' ', 			oils_i18n_gettext('881', 'Item is a music sound recording', 'ccvm', 'value')),
    (882, 'ltxt', 'a', 			oils_i18n_gettext('882', 'Autobiography', 'ccvm', 'value')),
    (883, 'ltxt', 'b', 			oils_i18n_gettext('883', 'Biography', 'ccvm', 'value')),
    (884, 'ltxt', 'c', 			oils_i18n_gettext('884', 'Conference proceedings', 'ccvm', 'value')),
    (885, 'ltxt', 'd', 			oils_i18n_gettext('885', 'Drama', 'ccvm', 'value')),
    (886, 'ltxt', 'e', 			oils_i18n_gettext('886', 'Essays', 'ccvm', 'value')),
    (887, 'ltxt', 'f', 			oils_i18n_gettext('887', 'Fiction', 'ccvm', 'value')),
    (888, 'ltxt', 'g', 			oils_i18n_gettext('888', 'Reporting', 'ccvm', 'value')),
    (889, 'ltxt', 'h', 			oils_i18n_gettext('889', 'History', 'ccvm', 'value')),
    (890, 'ltxt', 'i', 			oils_i18n_gettext('890', 'Instruction', 'ccvm', 'value')),
    (891, 'ltxt', 'j', 			oils_i18n_gettext('891', 'Language instruction', 'ccvm', 'value')),
    (892, 'ltxt', 'k', 			oils_i18n_gettext('892', 'Comedy', 'ccvm', 'value')),
    (893, 'ltxt', 'l', 			oils_i18n_gettext('893', 'Lectures, speeches', 'ccvm', 'value')),
    (894, 'ltxt', 'm', 			oils_i18n_gettext('894', 'Memoirs', 'ccvm', 'value')),
    (895, 'ltxt', 'n', 			oils_i18n_gettext('895', 'Not applicable', 'ccvm', 'value')),
    (896, 'ltxt', 'o', 			oils_i18n_gettext('896', 'Folktales', 'ccvm', 'value')),
    (897, 'ltxt', 'p', 			oils_i18n_gettext('897', 'Poetry', 'ccvm', 'value')),
    (898, 'ltxt', 'r', 			oils_i18n_gettext('898', 'Rehearsals', 'ccvm', 'value')),
    (899, 'ltxt', 's', 			oils_i18n_gettext('899', 'Sounds', 'ccvm', 'value')),
    (900, 'ltxt', 't', 			oils_i18n_gettext('900', 'Interviews', 'ccvm', 'value')),
    (901, 'ltxt', 'z', 			oils_i18n_gettext('901', 'Other', 'ccvm', 'value')),
	
    (902, 'orig', ' ', 			oils_i18n_gettext('902', 'None of the following', 'ccvm', 'value')),
    (903, 'orig', 'a', 			oils_i18n_gettext('903', 'Microfilm', 'ccvm', 'value')),
    (904, 'orig', 'b', 			oils_i18n_gettext('904', 'Microfiche', 'ccvm', 'value')),
    (905, 'orig', 'c', 			oils_i18n_gettext('905', 'Microopaque', 'ccvm', 'value')),
    (906, 'orig', 'd', 			oils_i18n_gettext('906', 'Large print', 'ccvm', 'value')),
    (907, 'orig', 'e', 			oils_i18n_gettext('907', 'Newspaper format', 'ccvm', 'value')),
    (908, 'orig', 'f', 			oils_i18n_gettext('908', 'Braille', 'ccvm', 'value')),
    (909, 'orig', 'o', 			oils_i18n_gettext('909', 'Online', 'ccvm', 'value')),
    (910, 'orig', 'q', 			oils_i18n_gettext('910', 'Direct electronic', 'ccvm', 'value')),
    (911, 'orig', 's', 			oils_i18n_gettext('911', 'Electronic', 'ccvm', 'value')),
	
    (912, 'part', ' ', 			oils_i18n_gettext('912', 'No parts in hand or not specified', 'ccvm', 'value')),
    (913, 'part', 'd', 			oils_i18n_gettext('913', 'Instrumental and vocal parts', 'ccvm', 'value')),
    (914, 'part', 'e', 			oils_i18n_gettext('914', 'Instrumental parts', 'ccvm', 'value')),
    (915, 'part', 'f', 			oils_i18n_gettext('915', 'Vocal parts', 'ccvm', 'value')),
    (916, 'part', 'n', 			oils_i18n_gettext('916', 'Not Applicable', 'ccvm', 'value')),
    (917, 'part', 'u', 			oils_i18n_gettext('917', 'Unknown', 'ccvm', 'value')),
	
    (918, 'proj', '  ', 		oils_i18n_gettext('918', 'Project not specified', 'ccvm', 'value')),
    (919, 'proj', 'aa', 		oils_i18n_gettext('919', 'Aitoff', 'ccvm', 'value')),
    (920, 'proj', 'ab', 		oils_i18n_gettext('920', 'Gnomic', 'ccvm', 'value')),
    (921, 'proj', 'ac', 		oils_i18n_gettext('921', 'Lambert''s azimuthal equal area', 'ccvm', 'value')),
    (922, 'proj', 'ad', 		oils_i18n_gettext('922', 'Orthographic', 'ccvm', 'value')),
    (923, 'proj', 'ae', 		oils_i18n_gettext('923', 'Azimuthal equidistant', 'ccvm', 'value')),
    (924, 'proj', 'af', 		oils_i18n_gettext('924', 'Stereographic', 'ccvm', 'value')),
    (925, 'proj', 'ag', 		oils_i18n_gettext('925', 'General vertical near-sided', 'ccvm', 'value')),
    (926, 'proj', 'am', 		oils_i18n_gettext('926', 'Modified stereographic for Alaska', 'ccvm', 'value')),
    (927, 'proj', 'an', 		oils_i18n_gettext('927', 'Chamberlin trimetric', 'ccvm', 'value')),
    (928, 'proj', 'ap', 		oils_i18n_gettext('928', 'Polar stereographic', 'ccvm', 'value')),
    (929, 'proj', 'au', 		oils_i18n_gettext('929', 'Azimuthal, specific type unknown', 'ccvm', 'value')),
    (930, 'proj', 'az', 		oils_i18n_gettext('930', 'Azimuthal, other', 'ccvm', 'value')),
    (931, 'proj', 'ba', 		oils_i18n_gettext('931', 'Gall', 'ccvm', 'value')),
    (932, 'proj', 'bb', 		oils_i18n_gettext('932', 'Goode''s homolographic', 'ccvm', 'value')),
    (933, 'proj', 'bc', 		oils_i18n_gettext('933', 'Lambert''s cylindrical equal area', 'ccvm', 'value')),
    (934, 'proj', 'bd', 		oils_i18n_gettext('934', 'Mercator', 'ccvm', 'value')),
    (935, 'proj', 'be', 		oils_i18n_gettext('935', 'Miller', 'ccvm', 'value')),
    (936, 'proj', 'bf', 		oils_i18n_gettext('936', 'Mollweide', 'ccvm', 'value')),
    (937, 'proj', 'bg', 		oils_i18n_gettext('937', 'Sinusoidal', 'ccvm', 'value')),
    (938, 'proj', 'bh', 		oils_i18n_gettext('938', 'Transverse Mercator', 'ccvm', 'value')),
    (939, 'proj', 'bi', 		oils_i18n_gettext('939', 'Gauss-Kruger', 'ccvm', 'value')),
    (940, 'proj', 'bj', 		oils_i18n_gettext('940', 'Equirectangular', 'ccvm', 'value')),
    (941, 'proj', 'bk', 		oils_i18n_gettext('941', 'Krovak', 'ccvm', 'value')),
    (942, 'proj', 'bl', 		oils_i18n_gettext('942', 'Cassini-Soldner', 'ccvm', 'value')),
    (943, 'proj', 'bo', 		oils_i18n_gettext('943', 'Oblique Mercator', 'ccvm', 'value')),
    (944, 'proj', 'br', 		oils_i18n_gettext('944', 'Robinson', 'ccvm', 'value')),
    (945, 'proj', 'bs', 		oils_i18n_gettext('945', 'Space oblique Mercator', 'ccvm', 'value')),
    (946, 'proj', 'bu', 		oils_i18n_gettext('946', 'Cylindrical, specific type unknown', 'ccvm', 'value')),
    (947, 'proj', 'bz', 		oils_i18n_gettext('947', 'Cylindrical, other', 'ccvm', 'value')),
    (948, 'proj', 'ca', 		oils_i18n_gettext('948', 'Alber''s equal area', 'ccvm', 'value')),
    (949, 'proj', 'cb', 		oils_i18n_gettext('949', 'Bonne', 'ccvm', 'value')),
    (950, 'proj', 'cc', 		oils_i18n_gettext('950', 'Lambert''s conformal conic', 'ccvm', 'value')),
    (951, 'proj', 'ce', 		oils_i18n_gettext('951', 'Equidistant conic', 'ccvm', 'value')),
    (952, 'proj', 'cp', 		oils_i18n_gettext('952', 'Polyconic', 'ccvm', 'value')),
    (953, 'proj', 'cu', 		oils_i18n_gettext('953', 'Conic, specific type unknown', 'ccvm', 'value')),
    (954, 'proj', 'cz', 		oils_i18n_gettext('954', 'Conic, other', 'ccvm', 'value')),
    (955, 'proj', 'da', 		oils_i18n_gettext('955', 'Armadillo', 'ccvm', 'value')),
    (956, 'proj', 'db', 		oils_i18n_gettext('956', 'Butterfly', 'ccvm', 'value')),
    (957, 'proj', 'dc', 		oils_i18n_gettext('957', 'Eckert', 'ccvm', 'value')),
    (958, 'proj', 'dd', 		oils_i18n_gettext('958', 'Goode''s homolosine', 'ccvm', 'value')),
    (959, 'proj', 'de', 		oils_i18n_gettext('959', 'Miller''s bipolar oblique conformal conic', 'ccvm', 'value')),
    (960, 'proj', 'df', 		oils_i18n_gettext('960', 'Van Der Grinten', 'ccvm', 'value')),
    (961, 'proj', 'dg', 		oils_i18n_gettext('961', 'Dymaxion', 'ccvm', 'value')),
    (962, 'proj', 'dh', 		oils_i18n_gettext('962', 'Cordiform', 'ccvm', 'value')),
    (963, 'proj', 'dl', 		oils_i18n_gettext('963', 'Lambert conformal', 'ccvm', 'value')),
    (964, 'proj', 'zz', 		oils_i18n_gettext('964', 'Other', 'ccvm', 'value')),
	
    (965, 'relf', ' ', 			oils_i18n_gettext('965', 'No relief shown', 'ccvm', 'value')),
    (966, 'relf', 'a', 			oils_i18n_gettext('966', 'Contours', 'ccvm', 'value')),
    (967, 'relf', 'b', 			oils_i18n_gettext('967', 'Shading', 'ccvm', 'value')),
    (968, 'relf', 'c', 			oils_i18n_gettext('968', 'Gradient and bathymetric tints', 'ccvm', 'value')),
    (969, 'relf', 'd', 			oils_i18n_gettext('969', 'Hachures', 'ccvm', 'value')),
    (970, 'relf', 'e', 			oils_i18n_gettext('970', 'Bathymetry, soundings', 'ccvm', 'value')),
    (971, 'relf', 'f', 			oils_i18n_gettext('971', 'Form lines', 'ccvm', 'value')),
    (972, 'relf', 'g', 			oils_i18n_gettext('972', 'Spot heights', 'ccvm', 'value')),
    (973, 'relf', 'i', 			oils_i18n_gettext('973', 'Pictorially', 'ccvm', 'value')),
    (974, 'relf', 'j', 			oils_i18n_gettext('974', 'Land forms', 'ccvm', 'value')),
    (975, 'relf', 'k', 			oils_i18n_gettext('975', 'Bathymetry, isolines', 'ccvm', 'value')),
    (976, 'relf', 'm', 			oils_i18n_gettext('976', 'Rock drawings', 'ccvm', 'value')),
    (977, 'relf', 'z', 			oils_i18n_gettext('977', 'Other', 'ccvm', 'value')),
	
    (978, 'spfm', ' ', 			oils_i18n_gettext('978', 'No specified special format characteristics', 'ccvm', 'value')),
    (979, 'spfm', 'e', 			oils_i18n_gettext('979', 'Manuscript', 'ccvm', 'value')),
    (980, 'spfm', 'j', 			oils_i18n_gettext('980', 'Picture card, post card', 'ccvm', 'value')),
    (981, 'spfm', 'k', 			oils_i18n_gettext('981', 'Calendar', 'ccvm', 'value')),
    (982, 'spfm', 'l', 			oils_i18n_gettext('982', 'Puzzle', 'ccvm', 'value')),
    (983, 'spfm', 'n', 			oils_i18n_gettext('983', 'Game', 'ccvm', 'value')),
    (984, 'spfm', 'o', 			oils_i18n_gettext('984', 'Wall map', 'ccvm', 'value')),
    (985, 'spfm', 'p', 			oils_i18n_gettext('985', 'Playing cards', 'ccvm', 'value')),
    (986, 'spfm', 'r', 			oils_i18n_gettext('986', 'Loose-leaf', 'ccvm', 'value')),
    (987, 'spfm', 'z', 			oils_i18n_gettext('987', 'Other', 'ccvm', 'value')),
	
    (988, 'srtp', ' ', 			oils_i18n_gettext('988', 'None of the following', 'ccvm', 'value')),
    (989, 'srtp', 'd', 			oils_i18n_gettext('989', 'Updating database', 'ccvm', 'value')),
    (990, 'srtp', 'l', 			oils_i18n_gettext('990', 'Updating loose-leaf', 'ccvm', 'value')),
    (991, 'srtp', 'm', 			oils_i18n_gettext('991', 'Monographic series', 'ccvm', 'value')),
    (992, 'srtp', 'n', 			oils_i18n_gettext('992', 'Newspaper', 'ccvm', 'value')),
    (993, 'srtp', 'p', 			oils_i18n_gettext('993', 'Periodical', 'ccvm', 'value')),
    (994, 'srtp', 'w', 			oils_i18n_gettext('994', 'Updating Web site', 'ccvm', 'value')),
	
    (995, 'tech', 'a', 			oils_i18n_gettext('995', 'Animation', 'ccvm', 'value')),
    (996, 'tech', 'c', 			oils_i18n_gettext('996', 'Animation and live action', 'ccvm', 'value')),
    (997, 'tech', 'l', 			oils_i18n_gettext('997', 'Live action', 'ccvm', 'value')),
    (998, 'tech', 'n', 			oils_i18n_gettext('998', 'Not applicable', 'ccvm', 'value')),
    (999, 'tech', 'u', 			oils_i18n_gettext('999', 'Unknown', 'ccvm', 'value')),
    (1000, 'tech', 'z', 		oils_i18n_gettext('1000', 'Other', 'ccvm', 'value')),
	
    (1001, 'trar', ' ', 		oils_i18n_gettext('1001', 'Not arrangement or transposition or not specified', 'ccvm', 'value')),
    (1002, 'trar', 'a', 		oils_i18n_gettext('1002', 'Transposition', 'ccvm', 'value')),
    (1003, 'trar', 'b', 		oils_i18n_gettext('1003', 'Arrangement', 'ccvm', 'value')),
    (1004, 'trar', 'c', 		oils_i18n_gettext('1004', 'Both transposed and arranged', 'ccvm', 'value')),
    (1005, 'trar', 'n', 		oils_i18n_gettext('1005', 'Not applicable', 'ccvm', 'value')),
    (1006, 'trar', 'u', 		oils_i18n_gettext('1006', 'Unknown', 'ccvm', 'value')),
	
    (1007, 'ctry', 'aa ', 		oils_i18n_gettext('1007', 'Albania ', 'ccvm', 'value')),
    (1008, 'ctry', 'abc', 		oils_i18n_gettext('1008', 'Alberta ', 'ccvm', 'value')),
    (1009, 'ctry', 'aca', 		oils_i18n_gettext('1009', 'Australian Capital Territory ', 'ccvm', 'value')),
    (1010, 'ctry', 'ae ', 		oils_i18n_gettext('1010', 'Algeria ', 'ccvm', 'value')),
    (1011, 'ctry', 'af ', 		oils_i18n_gettext('1011', 'Afghanistan ', 'ccvm', 'value')),
    (1012, 'ctry', 'ag ', 		oils_i18n_gettext('1012', 'Argentina ', 'ccvm', 'value')),
    (1013, 'ctry', 'ai ', 		oils_i18n_gettext('1013', 'Armenia (Republic) ', 'ccvm', 'value')),
    (1014, 'ctry', 'aj ', 		oils_i18n_gettext('1014', 'Azerbaijan ', 'ccvm', 'value')),
    (1015, 'ctry', 'aku', 		oils_i18n_gettext('1015', 'Alaska ', 'ccvm', 'value')),
    (1016, 'ctry', 'alu', 		oils_i18n_gettext('1016', 'Alabama ', 'ccvm', 'value')),
    (1017, 'ctry', 'am ', 		oils_i18n_gettext('1017', 'Anguilla ', 'ccvm', 'value')),
    (1018, 'ctry', 'an ', 		oils_i18n_gettext('1018', 'Andorra ', 'ccvm', 'value')),
    (1019, 'ctry', 'ao ', 		oils_i18n_gettext('1019', 'Angola ', 'ccvm', 'value')),
    (1020, 'ctry', 'aq ', 		oils_i18n_gettext('1020', 'Antigua and Barbuda ', 'ccvm', 'value')),
    (1021, 'ctry', 'aru', 		oils_i18n_gettext('1021', 'Arkansas ', 'ccvm', 'value')),
    (1022, 'ctry', 'as ', 		oils_i18n_gettext('1022', 'American Samoa ', 'ccvm', 'value')),
    (1023, 'ctry', 'at ', 		oils_i18n_gettext('1023', 'Australia ', 'ccvm', 'value')),
    (1024, 'ctry', 'au ', 		oils_i18n_gettext('1024', 'Austria ', 'ccvm', 'value')),
    (1025, 'ctry', 'aw ', 		oils_i18n_gettext('1025', 'Aruba ', 'ccvm', 'value')),
    (1026, 'ctry', 'ay ', 		oils_i18n_gettext('1026', 'Antarctica ', 'ccvm', 'value')),
    (1027, 'ctry', 'azu', 		oils_i18n_gettext('1027', 'Arizona ', 'ccvm', 'value')),
    (1028, 'ctry', 'ba ', 		oils_i18n_gettext('1028', 'Bahrain ', 'ccvm', 'value')),
    (1029, 'ctry', 'bb ', 		oils_i18n_gettext('1029', 'Barbados ', 'ccvm', 'value')),
    (1030, 'ctry', 'bcc', 		oils_i18n_gettext('1030', 'British Columbia ', 'ccvm', 'value')),
    (1031, 'ctry', 'bd ', 		oils_i18n_gettext('1031', 'Burundi ', 'ccvm', 'value')),
    (1032, 'ctry', 'be ', 		oils_i18n_gettext('1032', 'Belgium ', 'ccvm', 'value')),
    (1033, 'ctry', 'bf ', 		oils_i18n_gettext('1033', 'Bahamas ', 'ccvm', 'value')),
    (1034, 'ctry', 'bg ', 		oils_i18n_gettext('1034', 'Bangladesh ', 'ccvm', 'value')),
    (1035, 'ctry', 'bh ', 		oils_i18n_gettext('1035', 'Belize ', 'ccvm', 'value')),
    (1036, 'ctry', 'bi ', 		oils_i18n_gettext('1036', 'British Indian Ocean Territory ', 'ccvm', 'value')),
    (1037, 'ctry', 'bl ', 		oils_i18n_gettext('1037', 'Brazil ', 'ccvm', 'value')),
    (1038, 'ctry', 'bm ', 		oils_i18n_gettext('1038', 'Bermuda Islands ', 'ccvm', 'value')),
    (1039, 'ctry', 'bn ', 		oils_i18n_gettext('1039', 'Bosnia and Herzegovina ', 'ccvm', 'value')),
    (1040, 'ctry', 'bo ', 		oils_i18n_gettext('1040', 'Bolivia ', 'ccvm', 'value')),
    (1041, 'ctry', 'bp ', 		oils_i18n_gettext('1041', 'Solomon Islands ', 'ccvm', 'value')),
    (1042, 'ctry', 'br ', 		oils_i18n_gettext('1042', 'Burma ', 'ccvm', 'value')),
    (1043, 'ctry', 'bs ', 		oils_i18n_gettext('1043', 'Botswana ', 'ccvm', 'value')),
    (1044, 'ctry', 'bt ', 		oils_i18n_gettext('1044', 'Bhutan ', 'ccvm', 'value')),
    (1045, 'ctry', 'bu ', 		oils_i18n_gettext('1045', 'Bulgaria ', 'ccvm', 'value')),
    (1046, 'ctry', 'bv ', 		oils_i18n_gettext('1046', 'Bouvet Island ', 'ccvm', 'value')),
    (1047, 'ctry', 'bw ', 		oils_i18n_gettext('1047', 'Belarus ', 'ccvm', 'value')),
    (1048, 'ctry', 'bx ', 		oils_i18n_gettext('1048', 'Brunei ', 'ccvm', 'value')),
    (1049, 'ctry', 'ca ', 		oils_i18n_gettext('1049', 'Caribbean Netherlands ', 'ccvm', 'value')),
    (1050, 'ctry', 'cau', 		oils_i18n_gettext('1050', 'California ', 'ccvm', 'value')),
    (1051, 'ctry', 'cb ', 		oils_i18n_gettext('1051', 'Cambodia ', 'ccvm', 'value')),
    (1052, 'ctry', 'cc ', 		oils_i18n_gettext('1052', 'China ', 'ccvm', 'value')),
    (1053, 'ctry', 'cd ', 		oils_i18n_gettext('1053', 'Chad ', 'ccvm', 'value')),
    (1054, 'ctry', 'ce ', 		oils_i18n_gettext('1054', 'Sri Lanka ', 'ccvm', 'value')),
    (1055, 'ctry', 'cf ', 		oils_i18n_gettext('1055', 'Congo (Brazzaville) ', 'ccvm', 'value')),
    (1056, 'ctry', 'cg ', 		oils_i18n_gettext('1056', 'Congo (Democratic Republic) ', 'ccvm', 'value')),
    (1057, 'ctry', 'ch ', 		oils_i18n_gettext('1057', 'China (Republic : 1949', 'ccvm', 'value')),
    (1058, 'ctry', 'ci ', 		oils_i18n_gettext('1058', 'Croatia ', 'ccvm', 'value')),
    (1059, 'ctry', 'cj ', 		oils_i18n_gettext('1059', 'Cayman Islands ', 'ccvm', 'value')),
    (1060, 'ctry', 'ck ', 		oils_i18n_gettext('1060', 'Colombia ', 'ccvm', 'value')),
    (1061, 'ctry', 'cl ', 		oils_i18n_gettext('1061', 'Chile ', 'ccvm', 'value')),
    (1062, 'ctry', 'cm ', 		oils_i18n_gettext('1062', 'Cameroon ', 'ccvm', 'value')),
    (1063, 'ctry', 'co ', 		oils_i18n_gettext('1063', 'Curaçao ', 'ccvm', 'value')),
    (1064, 'ctry', 'cou', 		oils_i18n_gettext('1064', 'Colorado ', 'ccvm', 'value')),
    (1065, 'ctry', 'cq ', 		oils_i18n_gettext('1065', 'Comoros ', 'ccvm', 'value')),
    (1066, 'ctry', 'cr ', 		oils_i18n_gettext('1066', 'Costa Rica ', 'ccvm', 'value')),
    (1067, 'ctry', 'ctu', 		oils_i18n_gettext('1067', 'Connecticut ', 'ccvm', 'value')),
    (1068, 'ctry', 'cu ', 		oils_i18n_gettext('1068', 'Cuba ', 'ccvm', 'value')),
    (1069, 'ctry', 'cv ', 		oils_i18n_gettext('1069', 'Cabo Verde ', 'ccvm', 'value')),
    (1070, 'ctry', 'cw ', 		oils_i18n_gettext('1070', 'Cook Islands ', 'ccvm', 'value')),
    (1071, 'ctry', 'cx ', 		oils_i18n_gettext('1071', 'Central African Republic ', 'ccvm', 'value')),
    (1072, 'ctry', 'cy ', 		oils_i18n_gettext('1072', 'Cyprus ', 'ccvm', 'value')),
    (1073, 'ctry', 'dcu', 		oils_i18n_gettext('1073', 'District of Columbia ', 'ccvm', 'value')),
    (1074, 'ctry', 'deu', 		oils_i18n_gettext('1074', 'Delaware ', 'ccvm', 'value')),
    (1075, 'ctry', 'dk ', 		oils_i18n_gettext('1075', 'Denmark ', 'ccvm', 'value')),
    (1076, 'ctry', 'dm ', 		oils_i18n_gettext('1076', 'Benin ', 'ccvm', 'value')),
    (1077, 'ctry', 'dq ', 		oils_i18n_gettext('1077', 'Dominica ', 'ccvm', 'value')),
    (1078, 'ctry', 'dr ', 		oils_i18n_gettext('1078', 'Dominican Republic ', 'ccvm', 'value')),
    (1079, 'ctry', 'ea ', 		oils_i18n_gettext('1079', 'Eritrea ', 'ccvm', 'value')),
    (1080, 'ctry', 'ec ', 		oils_i18n_gettext('1080', 'Ecuador ', 'ccvm', 'value')),
    (1081, 'ctry', 'eg ', 		oils_i18n_gettext('1081', 'Equatorial Guinea ', 'ccvm', 'value')),
    (1082, 'ctry', 'em ', 		oils_i18n_gettext('1082', 'Timor', 'ccvm', 'value')),
    (1083, 'ctry', 'enk', 		oils_i18n_gettext('1083', 'England ', 'ccvm', 'value')),
    (1084, 'ctry', 'er ', 		oils_i18n_gettext('1084', 'Estonia ', 'ccvm', 'value')),
    (1085, 'ctry', 'es ', 		oils_i18n_gettext('1085', 'El Salvador ', 'ccvm', 'value')),
    (1086, 'ctry', 'et ', 		oils_i18n_gettext('1086', 'Ethiopia ', 'ccvm', 'value')),
    (1087, 'ctry', 'fa ', 		oils_i18n_gettext('1087', 'Faroe Islands ', 'ccvm', 'value')),
    (1088, 'ctry', 'fg ', 		oils_i18n_gettext('1088', 'French Guiana ', 'ccvm', 'value')),
    (1089, 'ctry', 'fi ', 		oils_i18n_gettext('1089', 'Finland ', 'ccvm', 'value')),
    (1090, 'ctry', 'fj ', 		oils_i18n_gettext('1090', 'Fiji ', 'ccvm', 'value')),
    (1091, 'ctry', 'fk ', 		oils_i18n_gettext('1091', 'Falkland Islands ', 'ccvm', 'value')),
    (1092, 'ctry', 'flu', 		oils_i18n_gettext('1092', 'Florida ', 'ccvm', 'value')),
    (1093, 'ctry', 'fm ', 		oils_i18n_gettext('1093', 'Micronesia (Federated States) ', 'ccvm', 'value')),
    (1094, 'ctry', 'fp ', 		oils_i18n_gettext('1094', 'French Polynesia ', 'ccvm', 'value')),
    (1095, 'ctry', 'fr ', 		oils_i18n_gettext('1095', 'France ', 'ccvm', 'value')),
    (1096, 'ctry', 'fs ', 		oils_i18n_gettext('1096', 'Terres australes et antarctiques françaises ', 'ccvm', 'value')),
    (1097, 'ctry', 'ft ', 		oils_i18n_gettext('1097', 'Djibouti ', 'ccvm', 'value')),
    (1098, 'ctry', 'gau', 		oils_i18n_gettext('1098', 'Georgia ', 'ccvm', 'value')),
    (1099, 'ctry', 'gb ', 		oils_i18n_gettext('1099', 'Kiribati ', 'ccvm', 'value')),
    (1100, 'ctry', 'gd ', 		oils_i18n_gettext('1100', 'Grenada ', 'ccvm', 'value')),
    (1101, 'ctry', 'gh ', 		oils_i18n_gettext('1101', 'Ghana ', 'ccvm', 'value')),
    (1102, 'ctry', 'gi ', 		oils_i18n_gettext('1102', 'Gibraltar ', 'ccvm', 'value')),
    (1103, 'ctry', 'gl ', 		oils_i18n_gettext('1103', 'Greenland ', 'ccvm', 'value')),
    (1104, 'ctry', 'gm ', 		oils_i18n_gettext('1104', 'Gambia ', 'ccvm', 'value')),
    (1105, 'ctry', 'go ', 		oils_i18n_gettext('1105', 'Gabon ', 'ccvm', 'value')),
    (1106, 'ctry', 'gp ', 		oils_i18n_gettext('1106', 'Guadeloupe ', 'ccvm', 'value')),
    (1107, 'ctry', 'gr ', 		oils_i18n_gettext('1107', 'Greece ', 'ccvm', 'value')),
    (1108, 'ctry', 'gs ', 		oils_i18n_gettext('1108', 'Georgia (Republic) ', 'ccvm', 'value')),
    (1109, 'ctry', 'gt ', 		oils_i18n_gettext('1109', 'Guatemala ', 'ccvm', 'value')),
    (1110, 'ctry', 'gu ', 		oils_i18n_gettext('1110', 'Guam ', 'ccvm', 'value')),
    (1111, 'ctry', 'gv ', 		oils_i18n_gettext('1111', 'Guinea ', 'ccvm', 'value')),
    (1112, 'ctry', 'gw ', 		oils_i18n_gettext('1112', 'Germany ', 'ccvm', 'value')),
    (1113, 'ctry', 'gy ', 		oils_i18n_gettext('1113', 'Guyana ', 'ccvm', 'value')),
    (1114, 'ctry', 'gz ', 		oils_i18n_gettext('1114', 'Gaza Strip ', 'ccvm', 'value')),
    (1115, 'ctry', 'hiu', 		oils_i18n_gettext('1115', 'Hawaii ', 'ccvm', 'value')),
    (1116, 'ctry', 'hm ', 		oils_i18n_gettext('1116', 'Heard and McDonald Islands ', 'ccvm', 'value')),
    (1117, 'ctry', 'ho ', 		oils_i18n_gettext('1117', 'Honduras ', 'ccvm', 'value')),
    (1118, 'ctry', 'ht ', 		oils_i18n_gettext('1118', 'Haiti ', 'ccvm', 'value')),
    (1119, 'ctry', 'hu ', 		oils_i18n_gettext('1119', 'Hungary ', 'ccvm', 'value')),
    (1120, 'ctry', 'iau', 		oils_i18n_gettext('1120', 'Iowa ', 'ccvm', 'value')),
    (1121, 'ctry', 'ic ', 		oils_i18n_gettext('1121', 'Iceland ', 'ccvm', 'value')),
    (1122, 'ctry', 'idu', 		oils_i18n_gettext('1122', 'Idaho ', 'ccvm', 'value')),
    (1123, 'ctry', 'ie ', 		oils_i18n_gettext('1123', 'Ireland ', 'ccvm', 'value')),
    (1124, 'ctry', 'ii ', 		oils_i18n_gettext('1124', 'India ', 'ccvm', 'value')),
    (1125, 'ctry', 'ilu', 		oils_i18n_gettext('1125', 'Illinois ', 'ccvm', 'value')),
    (1126, 'ctry', 'inu', 		oils_i18n_gettext('1126', 'Indiana ', 'ccvm', 'value')),
    (1127, 'ctry', 'io ', 		oils_i18n_gettext('1127', 'Indonesia ', 'ccvm', 'value')),
    (1128, 'ctry', 'iq ', 		oils_i18n_gettext('1128', 'Iraq ', 'ccvm', 'value')),
    (1129, 'ctry', 'ir ', 		oils_i18n_gettext('1129', 'Iran ', 'ccvm', 'value')),
    (1130, 'ctry', 'is ', 		oils_i18n_gettext('1130', 'Israel ', 'ccvm', 'value')),
    (1131, 'ctry', 'it ', 		oils_i18n_gettext('1131', 'Italy ', 'ccvm', 'value')),
    (1132, 'ctry', 'iv ', 		oils_i18n_gettext('1132', 'Côte d''Ivoire ', 'ccvm', 'value')),
    (1133, 'ctry', 'iy ', 		oils_i18n_gettext('1133', 'Iraq', 'ccvm', 'value')),
    (1134, 'ctry', 'ja ', 		oils_i18n_gettext('1134', 'Japan ', 'ccvm', 'value')),
    (1135, 'ctry', 'ji ', 		oils_i18n_gettext('1135', 'Johnston Atoll ', 'ccvm', 'value')),
    (1136, 'ctry', 'jm ', 		oils_i18n_gettext('1136', 'Jamaica ', 'ccvm', 'value')),
    (1137, 'ctry', 'jo ', 		oils_i18n_gettext('1137', 'Jordan ', 'ccvm', 'value')),
    (1138, 'ctry', 'ke ', 		oils_i18n_gettext('1138', 'Kenya ', 'ccvm', 'value')),
    (1139, 'ctry', 'kg ', 		oils_i18n_gettext('1139', 'Kyrgyzstan ', 'ccvm', 'value')),
    (1140, 'ctry', 'kn ', 		oils_i18n_gettext('1140', 'Korea (North) ', 'ccvm', 'value')),
    (1141, 'ctry', 'ko ', 		oils_i18n_gettext('1141', 'Korea (South) ', 'ccvm', 'value')),
    (1142, 'ctry', 'ksu', 		oils_i18n_gettext('1142', 'Kansas ', 'ccvm', 'value')),
    (1143, 'ctry', 'ku ', 		oils_i18n_gettext('1143', 'Kuwait ', 'ccvm', 'value')),
    (1144, 'ctry', 'kv ', 		oils_i18n_gettext('1144', 'Kosovo ', 'ccvm', 'value')),
    (1145, 'ctry', 'kyu', 		oils_i18n_gettext('1145', 'Kentucky ', 'ccvm', 'value')),
    (1146, 'ctry', 'kz ', 		oils_i18n_gettext('1146', 'Kazakhstan ', 'ccvm', 'value')),
    (1147, 'ctry', 'lau', 		oils_i18n_gettext('1147', 'Louisiana ', 'ccvm', 'value')),
    (1148, 'ctry', 'lb ', 		oils_i18n_gettext('1148', 'Liberia ', 'ccvm', 'value')),
    (1149, 'ctry', 'le ', 		oils_i18n_gettext('1149', 'Lebanon ', 'ccvm', 'value')),
    (1150, 'ctry', 'lh ', 		oils_i18n_gettext('1150', 'Liechtenstein ', 'ccvm', 'value')),
    (1151, 'ctry', 'li ', 		oils_i18n_gettext('1151', 'Lithuania ', 'ccvm', 'value')),
    (1152, 'ctry', 'lo ', 		oils_i18n_gettext('1152', 'Lesotho ', 'ccvm', 'value')),
    (1153, 'ctry', 'ls ', 		oils_i18n_gettext('1153', 'Laos ', 'ccvm', 'value')),
    (1154, 'ctry', 'lu ', 		oils_i18n_gettext('1154', 'Luxembourg ', 'ccvm', 'value')),
    (1155, 'ctry', 'lv ', 		oils_i18n_gettext('1155', 'Latvia ', 'ccvm', 'value')),
    (1156, 'ctry', 'ly ', 		oils_i18n_gettext('1156', 'Libya ', 'ccvm', 'value')),
    (1157, 'ctry', 'mau', 		oils_i18n_gettext('1157', 'Massachusetts ', 'ccvm', 'value')),
    (1158, 'ctry', 'mbc', 		oils_i18n_gettext('1158', 'Manitoba ', 'ccvm', 'value')),
    (1159, 'ctry', 'mc ', 		oils_i18n_gettext('1159', 'Monaco ', 'ccvm', 'value')),
    (1160, 'ctry', 'mdu', 		oils_i18n_gettext('1160', 'Maryland ', 'ccvm', 'value')),
    (1161, 'ctry', 'meu', 		oils_i18n_gettext('1161', 'Maine ', 'ccvm', 'value')),
    (1162, 'ctry', 'mf ', 		oils_i18n_gettext('1162', 'Mauritius ', 'ccvm', 'value')),
    (1163, 'ctry', 'mg ', 		oils_i18n_gettext('1163', 'Madagascar ', 'ccvm', 'value')),
    (1164, 'ctry', 'miu', 		oils_i18n_gettext('1164', 'Michigan ', 'ccvm', 'value')),
    (1165, 'ctry', 'mj ', 		oils_i18n_gettext('1165', 'Montserrat ', 'ccvm', 'value')),
    (1166, 'ctry', 'mk ', 		oils_i18n_gettext('1166', 'Oman ', 'ccvm', 'value')),
    (1167, 'ctry', 'ml ', 		oils_i18n_gettext('1167', 'Mali ', 'ccvm', 'value')),
    (1168, 'ctry', 'mm ', 		oils_i18n_gettext('1168', 'Malta ', 'ccvm', 'value')),
    (1169, 'ctry', 'mnu', 		oils_i18n_gettext('1169', 'Minnesota ', 'ccvm', 'value')),
    (1170, 'ctry', 'mo ', 		oils_i18n_gettext('1170', 'Montenegro ', 'ccvm', 'value')),
    (1171, 'ctry', 'mou', 		oils_i18n_gettext('1171', 'Missouri ', 'ccvm', 'value')),
    (1172, 'ctry', 'mp ', 		oils_i18n_gettext('1172', 'Mongolia ', 'ccvm', 'value')),
    (1173, 'ctry', 'mq ', 		oils_i18n_gettext('1173', 'Martinique ', 'ccvm', 'value')),
    (1174, 'ctry', 'mr ', 		oils_i18n_gettext('1174', 'Morocco ', 'ccvm', 'value')),
    (1175, 'ctry', 'msu', 		oils_i18n_gettext('1175', 'Mississippi ', 'ccvm', 'value')),
    (1176, 'ctry', 'mtu', 		oils_i18n_gettext('1176', 'Montana ', 'ccvm', 'value')),
    (1177, 'ctry', 'mu ', 		oils_i18n_gettext('1177', 'Mauritania ', 'ccvm', 'value')),
    (1178, 'ctry', 'mv ', 		oils_i18n_gettext('1178', 'Moldova ', 'ccvm', 'value')),
    (1179, 'ctry', 'mw ', 		oils_i18n_gettext('1179', 'Malawi ', 'ccvm', 'value')),
    (1180, 'ctry', 'mx ', 		oils_i18n_gettext('1180', 'Mexico ', 'ccvm', 'value')),
    (1181, 'ctry', 'my ', 		oils_i18n_gettext('1181', 'Malaysia ', 'ccvm', 'value')),
    (1182, 'ctry', 'mz ', 		oils_i18n_gettext('1182', 'Mozambique ', 'ccvm', 'value')),
    (1183, 'ctry', 'nbu', 		oils_i18n_gettext('1183', 'Nebraska ', 'ccvm', 'value')),
    (1184, 'ctry', 'ncu', 		oils_i18n_gettext('1184', 'North Carolina ', 'ccvm', 'value')),
    (1185, 'ctry', 'ndu', 		oils_i18n_gettext('1185', 'North Dakota ', 'ccvm', 'value')),
    (1186, 'ctry', 'ne ', 		oils_i18n_gettext('1186', 'Netherlands ', 'ccvm', 'value')),
    (1187, 'ctry', 'nfc', 		oils_i18n_gettext('1187', 'Newfoundland and Labrador ', 'ccvm', 'value')),
    (1188, 'ctry', 'ng ', 		oils_i18n_gettext('1188', 'Niger ', 'ccvm', 'value')),
    (1189, 'ctry', 'nhu', 		oils_i18n_gettext('1189', 'New Hampshire ', 'ccvm', 'value')),
    (1190, 'ctry', 'nik', 		oils_i18n_gettext('1190', 'Northern Ireland ', 'ccvm', 'value')),
    (1191, 'ctry', 'nju', 		oils_i18n_gettext('1191', 'New Jersey ', 'ccvm', 'value')),
    (1192, 'ctry', 'nkc', 		oils_i18n_gettext('1192', 'New Brunswick ', 'ccvm', 'value')),
    (1193, 'ctry', 'nl ', 		oils_i18n_gettext('1193', 'New Caledonia ', 'ccvm', 'value')),
    (1194, 'ctry', 'nmu', 		oils_i18n_gettext('1194', 'New Mexico ', 'ccvm', 'value')),
    (1195, 'ctry', 'nn ', 		oils_i18n_gettext('1195', 'Vanuatu ', 'ccvm', 'value')),
    (1196, 'ctry', 'no ', 		oils_i18n_gettext('1196', 'Norway ', 'ccvm', 'value')),
    (1197, 'ctry', 'np ', 		oils_i18n_gettext('1197', 'Nepal ', 'ccvm', 'value')),
    (1198, 'ctry', 'nq ', 		oils_i18n_gettext('1198', 'Nicaragua ', 'ccvm', 'value')),
    (1199, 'ctry', 'nr ', 		oils_i18n_gettext('1199', 'Nigeria ', 'ccvm', 'value')),
    (1200, 'ctry', 'nsc', 		oils_i18n_gettext('1200', 'Nova Scotia ', 'ccvm', 'value')),
    (1201, 'ctry', 'ntc', 		oils_i18n_gettext('1201', 'Northwest Territories ', 'ccvm', 'value')),
    (1202, 'ctry', 'nu ', 		oils_i18n_gettext('1202', 'Nauru ', 'ccvm', 'value')),
    (1203, 'ctry', 'nuc', 		oils_i18n_gettext('1203', 'Nunavut ', 'ccvm', 'value')),
    (1204, 'ctry', 'nvu', 		oils_i18n_gettext('1204', 'Nevada ', 'ccvm', 'value')),
    (1205, 'ctry', 'nw ', 		oils_i18n_gettext('1205', 'Northern Mariana Islands ', 'ccvm', 'value')),
    (1206, 'ctry', 'nx ', 		oils_i18n_gettext('1206', 'Norfolk Island ', 'ccvm', 'value')),
    (1207, 'ctry', 'nyu', 		oils_i18n_gettext('1207', 'New York (State) ', 'ccvm', 'value')),
    (1208, 'ctry', 'nz ', 		oils_i18n_gettext('1208', 'New Zealand ', 'ccvm', 'value')),
    (1209, 'ctry', 'ohu', 		oils_i18n_gettext('1209', 'Ohio ', 'ccvm', 'value')),
    (1210, 'ctry', 'oku', 		oils_i18n_gettext('1210', 'Oklahoma ', 'ccvm', 'value')),
    (1211, 'ctry', 'onc', 		oils_i18n_gettext('1211', 'Ontario ', 'ccvm', 'value')),
    (1212, 'ctry', 'oru', 		oils_i18n_gettext('1212', 'Oregon ', 'ccvm', 'value')),
    (1213, 'ctry', 'ot ', 		oils_i18n_gettext('1213', 'Mayotte ', 'ccvm', 'value')),
    (1214, 'ctry', 'pau', 		oils_i18n_gettext('1214', 'Pennsylvania ', 'ccvm', 'value')),
    (1215, 'ctry', 'pc ', 		oils_i18n_gettext('1215', 'Pitcairn Island ', 'ccvm', 'value')),
    (1216, 'ctry', 'pe ', 		oils_i18n_gettext('1216', 'Peru ', 'ccvm', 'value')),
    (1217, 'ctry', 'pf ', 		oils_i18n_gettext('1217', 'Paracel Islands ', 'ccvm', 'value')),
    (1218, 'ctry', 'pg ', 		oils_i18n_gettext('1218', 'Guinea', 'ccvm', 'value')),
    (1219, 'ctry', 'ph ', 		oils_i18n_gettext('1219', 'Philippines ', 'ccvm', 'value')),
    (1220, 'ctry', 'pic', 		oils_i18n_gettext('1220', 'Prince Edward Island ', 'ccvm', 'value')),
    (1221, 'ctry', 'pk ', 		oils_i18n_gettext('1221', 'Pakistan ', 'ccvm', 'value')),
    (1222, 'ctry', 'pl ', 		oils_i18n_gettext('1222', 'Poland ', 'ccvm', 'value')),
    (1223, 'ctry', 'pn ', 		oils_i18n_gettext('1223', 'Panama ', 'ccvm', 'value')),
    (1224, 'ctry', 'po ', 		oils_i18n_gettext('1224', 'Portugal ', 'ccvm', 'value')),
    (1225, 'ctry', 'pp ', 		oils_i18n_gettext('1225', 'Papua New Guinea ', 'ccvm', 'value')),
    (1226, 'ctry', 'pr ', 		oils_i18n_gettext('1226', 'Puerto Rico ', 'ccvm', 'value')),
    (1227, 'ctry', 'pw ', 		oils_i18n_gettext('1227', 'Palau ', 'ccvm', 'value')),
    (1228, 'ctry', 'py ', 		oils_i18n_gettext('1228', 'Paraguay ', 'ccvm', 'value')),
    (1229, 'ctry', 'qa ', 		oils_i18n_gettext('1229', 'Qatar ', 'ccvm', 'value')),
    (1230, 'ctry', 'qea', 		oils_i18n_gettext('1230', 'Queensland ', 'ccvm', 'value')),
    (1231, 'ctry', 'quc', 		oils_i18n_gettext('1231', 'Québec (Province) ', 'ccvm', 'value')),
    (1232, 'ctry', 'rb ', 		oils_i18n_gettext('1232', 'Serbia ', 'ccvm', 'value')),
    (1233, 'ctry', 're ', 		oils_i18n_gettext('1233', 'Réunion ', 'ccvm', 'value')),
    (1234, 'ctry', 'rh ', 		oils_i18n_gettext('1234', 'Zimbabwe ', 'ccvm', 'value')),
    (1235, 'ctry', 'riu', 		oils_i18n_gettext('1235', 'Rhode Island ', 'ccvm', 'value')),
    (1236, 'ctry', 'rm ', 		oils_i18n_gettext('1236', 'Romania ', 'ccvm', 'value')),
    (1237, 'ctry', 'ru ', 		oils_i18n_gettext('1237', 'Russia (Federation) ', 'ccvm', 'value')),
    (1238, 'ctry', 'rw ', 		oils_i18n_gettext('1238', 'Rwanda ', 'ccvm', 'value')),
    (1239, 'ctry', 'sa ', 		oils_i18n_gettext('1239', 'South Africa ', 'ccvm', 'value')),
    (1240, 'ctry', 'sc ', 		oils_i18n_gettext('1240', 'Saint', 'ccvm', 'value')),
    (1241, 'ctry', 'scu', 		oils_i18n_gettext('1241', 'South Carolina ', 'ccvm', 'value')),
    (1242, 'ctry', 'sd ', 		oils_i18n_gettext('1242', 'South Sudan ', 'ccvm', 'value')),
    (1243, 'ctry', 'sdu', 		oils_i18n_gettext('1243', 'South Dakota ', 'ccvm', 'value')),
    (1244, 'ctry', 'se ', 		oils_i18n_gettext('1244', 'Seychelles ', 'ccvm', 'value')),
    (1245, 'ctry', 'sf ', 		oils_i18n_gettext('1245', 'Sao Tome and Principe ', 'ccvm', 'value')),
    (1246, 'ctry', 'sg ', 		oils_i18n_gettext('1246', 'Senegal ', 'ccvm', 'value')),
    (1247, 'ctry', 'sh ', 		oils_i18n_gettext('1247', 'Spanish North Africa ', 'ccvm', 'value')),
    (1248, 'ctry', 'si ', 		oils_i18n_gettext('1248', 'Singapore ', 'ccvm', 'value')),
    (1249, 'ctry', 'sj ', 		oils_i18n_gettext('1249', 'Sudan ', 'ccvm', 'value')),
    (1250, 'ctry', 'sl ', 		oils_i18n_gettext('1250', 'Sierra Leone ', 'ccvm', 'value')),
    (1251, 'ctry', 'sm ', 		oils_i18n_gettext('1251', 'San Marino ', 'ccvm', 'value')),
    (1252, 'ctry', 'sn ', 		oils_i18n_gettext('1252', 'Sint Maarten ', 'ccvm', 'value')),
    (1253, 'ctry', 'snc', 		oils_i18n_gettext('1253', 'Saskatchewan ', 'ccvm', 'value')),
    (1254, 'ctry', 'so ', 		oils_i18n_gettext('1254', 'Somalia ', 'ccvm', 'value')),
    (1255, 'ctry', 'sp ', 		oils_i18n_gettext('1255', 'Spain ', 'ccvm', 'value')),
    (1256, 'ctry', 'sq ', 		oils_i18n_gettext('1256', 'Swaziland ', 'ccvm', 'value')),
    (1257, 'ctry', 'sr ', 		oils_i18n_gettext('1257', 'Surinam ', 'ccvm', 'value')),
    (1258, 'ctry', 'ss ', 		oils_i18n_gettext('1258', 'Western Sahara ', 'ccvm', 'value')),
    (1259, 'ctry', 'st ', 		oils_i18n_gettext('1259', 'Saint', 'ccvm', 'value')),
    (1260, 'ctry', 'stk', 		oils_i18n_gettext('1260', 'Scotland ', 'ccvm', 'value')),
    (1261, 'ctry', 'su ', 		oils_i18n_gettext('1261', 'Saudi Arabia ', 'ccvm', 'value')),
    (1262, 'ctry', 'sw ', 		oils_i18n_gettext('1262', 'Sweden ', 'ccvm', 'value')),
    (1263, 'ctry', 'sx ', 		oils_i18n_gettext('1263', 'Namibia ', 'ccvm', 'value')),
    (1264, 'ctry', 'sy ', 		oils_i18n_gettext('1264', 'Syria ', 'ccvm', 'value')),
    (1265, 'ctry', 'sz ', 		oils_i18n_gettext('1265', 'Switzerland ', 'ccvm', 'value')),
    (1266, 'ctry', 'ta ', 		oils_i18n_gettext('1266', 'Tajikistan ', 'ccvm', 'value')),
    (1267, 'ctry', 'tc ', 		oils_i18n_gettext('1267', 'Turks and Caicos Islands ', 'ccvm', 'value')),
    (1268, 'ctry', 'tg ', 		oils_i18n_gettext('1268', 'Togo ', 'ccvm', 'value')),
    (1269, 'ctry', 'th ', 		oils_i18n_gettext('1269', 'Thailand ', 'ccvm', 'value')),
    (1270, 'ctry', 'ti ', 		oils_i18n_gettext('1270', 'Tunisia ', 'ccvm', 'value')),
    (1271, 'ctry', 'tk ', 		oils_i18n_gettext('1271', 'Turkmenistan ', 'ccvm', 'value')),
    (1272, 'ctry', 'tl ', 		oils_i18n_gettext('1272', 'Tokelau ', 'ccvm', 'value')),
    (1273, 'ctry', 'tma', 		oils_i18n_gettext('1273', 'Tasmania ', 'ccvm', 'value')),
    (1274, 'ctry', 'tnu', 		oils_i18n_gettext('1274', 'Tennessee ', 'ccvm', 'value')),
    (1275, 'ctry', 'to ', 		oils_i18n_gettext('1275', 'Tonga ', 'ccvm', 'value')),
    (1276, 'ctry', 'tr ', 		oils_i18n_gettext('1276', 'Trinidad and Tobago ', 'ccvm', 'value')),
    (1277, 'ctry', 'ts ', 		oils_i18n_gettext('1277', 'United Arab Emirates ', 'ccvm', 'value')),
    (1278, 'ctry', 'tu ', 		oils_i18n_gettext('1278', 'Turkey ', 'ccvm', 'value')),
    (1279, 'ctry', 'tv ', 		oils_i18n_gettext('1279', 'Tuvalu ', 'ccvm', 'value')),
    (1280, 'ctry', 'txu', 		oils_i18n_gettext('1280', 'Texas ', 'ccvm', 'value')),
    (1281, 'ctry', 'tz ', 		oils_i18n_gettext('1281', 'Tanzania ', 'ccvm', 'value')),
    (1282, 'ctry', 'ua ', 		oils_i18n_gettext('1282', 'Egypt ', 'ccvm', 'value')),
    (1283, 'ctry', 'uc ', 		oils_i18n_gettext('1283', 'United States Misc. Caribbean Islands ', 'ccvm', 'value')),
    (1284, 'ctry', 'ug ', 		oils_i18n_gettext('1284', 'Uganda ', 'ccvm', 'value')),
    (1285, 'ctry', 'uik', 		oils_i18n_gettext('1285', 'United Kingdom Misc. Islands ', 'ccvm', 'value')),
    (1286, 'ctry', 'un ', 		oils_i18n_gettext('1286', 'Ukraine ', 'ccvm', 'value')),
    (1287, 'ctry', 'up ', 		oils_i18n_gettext('1287', 'United States Misc. Pacific Islands ', 'ccvm', 'value')),
    (1288, 'ctry', 'utu', 		oils_i18n_gettext('1288', 'Utah ', 'ccvm', 'value')),
    (1289, 'ctry', 'uv ', 		oils_i18n_gettext('1289', 'Burkina Faso ', 'ccvm', 'value')),
    (1290, 'ctry', 'uy ', 		oils_i18n_gettext('1290', 'Uruguay ', 'ccvm', 'value')),
    (1291, 'ctry', 'uz ', 		oils_i18n_gettext('1291', 'Uzbekistan ', 'ccvm', 'value')),
    (1292, 'ctry', 'vau', 		oils_i18n_gettext('1292', 'Virginia ', 'ccvm', 'value')),
    (1293, 'ctry', 'vb ', 		oils_i18n_gettext('1293', 'British Virgin Islands ', 'ccvm', 'value')),
    (1294, 'ctry', 'vc ', 		oils_i18n_gettext('1294', 'Vatican City ', 'ccvm', 'value')),
    (1295, 'ctry', 've ', 		oils_i18n_gettext('1295', 'Venezuela ', 'ccvm', 'value')),
    (1296, 'ctry', 'vi ', 		oils_i18n_gettext('1296', 'Virgin Islands of the United States ', 'ccvm', 'value')),
    (1297, 'ctry', 'vm ', 		oils_i18n_gettext('1297', 'Vietnam ', 'ccvm', 'value')),
    (1298, 'ctry', 'vp ', 		oils_i18n_gettext('1298', 'Various places ', 'ccvm', 'value')),
    (1299, 'ctry', 'vra', 		oils_i18n_gettext('1299', 'Victoria ', 'ccvm', 'value')),
    (1300, 'ctry', 'vtu', 		oils_i18n_gettext('1300', 'Vermont ', 'ccvm', 'value')),
    (1301, 'ctry', 'wau', 		oils_i18n_gettext('1301', 'Washington (State) ', 'ccvm', 'value')),
    (1302, 'ctry', 'wea', 		oils_i18n_gettext('1302', 'Western Australia ', 'ccvm', 'value')),
    (1303, 'ctry', 'wf ', 		oils_i18n_gettext('1303', 'Wallis and Futuna ', 'ccvm', 'value')),
    (1304, 'ctry', 'wiu', 		oils_i18n_gettext('1304', 'Wisconsin ', 'ccvm', 'value')),
    (1305, 'ctry', 'wj ', 		oils_i18n_gettext('1305', 'West Bank of the Jordan River ', 'ccvm', 'value')),
    (1306, 'ctry', 'wk ', 		oils_i18n_gettext('1306', 'Wake Island ', 'ccvm', 'value')),
    (1307, 'ctry', 'wlk', 		oils_i18n_gettext('1307', 'Wales ', 'ccvm', 'value')),
    (1308, 'ctry', 'ws ', 		oils_i18n_gettext('1308', 'Samoa ', 'ccvm', 'value')),
    (1309, 'ctry', 'wvu', 		oils_i18n_gettext('1309', 'West Virginia ', 'ccvm', 'value')),
    (1310, 'ctry', 'wyu', 		oils_i18n_gettext('1310', 'Wyoming ', 'ccvm', 'value')),
    (1311, 'ctry', 'xa ', 		oils_i18n_gettext('1311', 'Christmas Island (Indian Ocean) ', 'ccvm', 'value')),
    (1312, 'ctry', 'xb ', 		oils_i18n_gettext('1312', 'Cocos (Keeling) Islands ', 'ccvm', 'value')),
    (1313, 'ctry', 'xc ', 		oils_i18n_gettext('1313', 'Maldives ', 'ccvm', 'value')),
    (1314, 'ctry', 'xd ', 		oils_i18n_gettext('1314', 'Saint Kitts', 'ccvm', 'value')),
    (1315, 'ctry', 'xe ', 		oils_i18n_gettext('1315', 'Marshall Islands ', 'ccvm', 'value')),
    (1316, 'ctry', 'xf ', 		oils_i18n_gettext('1316', 'Midway Islands ', 'ccvm', 'value')),
    (1317, 'ctry', 'xga', 		oils_i18n_gettext('1317', 'Coral Sea Islands Territory ', 'ccvm', 'value')),
    (1318, 'ctry', 'xh ', 		oils_i18n_gettext('1318', 'Niue ', 'ccvm', 'value')),
    (1319, 'ctry', 'xj ', 		oils_i18n_gettext('1319', 'Saint Helena ', 'ccvm', 'value')),
    (1320, 'ctry', 'xk ', 		oils_i18n_gettext('1320', 'Saint Lucia ', 'ccvm', 'value')),
    (1321, 'ctry', 'xl ', 		oils_i18n_gettext('1321', 'Saint Pierre and Miquelon ', 'ccvm', 'value')),
    (1322, 'ctry', 'xm ', 		oils_i18n_gettext('1322', 'Saint Vincent and the Grenadines ', 'ccvm', 'value')),
    (1323, 'ctry', 'xn ', 		oils_i18n_gettext('1323', 'Macedonia ', 'ccvm', 'value')),
    (1324, 'ctry', 'xna', 		oils_i18n_gettext('1324', 'New South Wales ', 'ccvm', 'value')),
    (1325, 'ctry', 'xo ', 		oils_i18n_gettext('1325', 'Slovakia ', 'ccvm', 'value')),
    (1326, 'ctry', 'xoa', 		oils_i18n_gettext('1326', 'Northern Territory ', 'ccvm', 'value')),
    (1327, 'ctry', 'xp ', 		oils_i18n_gettext('1327', 'Spratly Island ', 'ccvm', 'value')),
    (1328, 'ctry', 'xr ', 		oils_i18n_gettext('1328', 'Czech Republic ', 'ccvm', 'value')),
    (1329, 'ctry', 'xra', 		oils_i18n_gettext('1329', 'South Australia ', 'ccvm', 'value')),
    (1330, 'ctry', 'xs ', 		oils_i18n_gettext('1330', 'South Georgia and the South Sandwich Islands ', 'ccvm', 'value')),
    (1331, 'ctry', 'xv ', 		oils_i18n_gettext('1331', 'Slovenia ', 'ccvm', 'value')),
    (1332, 'ctry', 'xx ', 		oils_i18n_gettext('1332', 'No place, unknown, or undetermined ', 'ccvm', 'value')),
    (1333, 'ctry', 'xxc', 		oils_i18n_gettext('1333', 'Canada ', 'ccvm', 'value')),
    (1334, 'ctry', 'xxk', 		oils_i18n_gettext('1334', 'United Kingdom ', 'ccvm', 'value')),
    (1335, 'ctry', 'xxu', 		oils_i18n_gettext('1335', 'United States ', 'ccvm', 'value')),
    (1336, 'ctry', 'ye ', 		oils_i18n_gettext('1336', 'Yemen ', 'ccvm', 'value')),
    (1337, 'ctry', 'ykc', 		oils_i18n_gettext('1337', 'Yukon Territory ', 'ccvm', 'value')),
    (1338, 'ctry', 'za ', 		oils_i18n_gettext('1338', 'Zambia ', 'ccvm', 'value')),
	
    (1339, 'pub_status', 'b', 	oils_i18n_gettext('1339', 'No dates given; B.C. date involved', 'ccvm', 'value')),
    (1340, 'pub_status', 'c', 	oils_i18n_gettext('1340', 'Continuing resource currently published', 'ccvm', 'value')),
    (1341, 'pub_status', 'd', 	oils_i18n_gettext('1341', 'Continuing resource ceased publication', 'ccvm', 'value')),
    (1342, 'pub_status', 'e', 	oils_i18n_gettext('1342', 'Detailed date', 'ccvm', 'value')),
    (1343, 'pub_status', 'i', 	oils_i18n_gettext('1343', 'Inclusive dates of collection', 'ccvm', 'value')),
    (1344, 'pub_status', 'k', 	oils_i18n_gettext('1344', 'Range of years of bulk of collection', 'ccvm', 'value')),
    (1345, 'pub_status', 'm', 	oils_i18n_gettext('1345', 'Multiple dates', 'ccvm', 'value')),
    (1346, 'pub_status', 'n', 	oils_i18n_gettext('1346', 'Dates unknown', 'ccvm', 'value')),
    (1347, 'pub_status', 'p', 	oils_i18n_gettext('1347', 'Date of distribution/release/issue and production/recording session when different', 'ccvm', 'value')),
    (1348, 'pub_status', 'q', 	oils_i18n_gettext('1348', 'Questionable date', 'ccvm', 'value')),
    (1349, 'pub_status', 'r', 	oils_i18n_gettext('1349', 'Reprint/reissue date and original date', 'ccvm', 'value')),
    (1350, 'pub_status', 's', 	oils_i18n_gettext('1350', 'Single known date/probable date', 'ccvm', 'value')),
    (1351, 'pub_status', 't', 	oils_i18n_gettext('1351', 'Publication date and copyright date', 'ccvm', 'value')),
    (1352, 'pub_status', 'u', 	oils_i18n_gettext('1352', 'Continuing resource status unknown', 'ccvm', 'value'));
	

-- These are fixed fields that are made up of multiple single-character codes. These are the actual fields that are used to define relevent attributes,
-- the "unnumbered" version of these fields are used for the MARC editor and as composite attributes for use in the OPAC if desired.
-- i18n ids are left as-is because there's no need to have multiple translations for the same value.
-- The ' ' codes only apply to the first position because if there's anything in pos 1 then the rest of the spaces are just filler.
-- There's also no need for them to be opac visible because there will be composite attributes that OR these numbered attributes together.
INSERT INTO config.coded_value_map (id, ctype, code, value, opac_visible) VALUES
    (1353, 'accm1', ' ', 	oils_i18n_gettext('1735', 'No accompanying matter', 'ccvm', 'value'), FALSE),
    (1354, 'accm1', 'a', 	oils_i18n_gettext('713', 'Discography', 'ccvm', 'value'), FALSE),
    (1355, 'accm1', 'b', 	oils_i18n_gettext('714', 'Bibliography', 'ccvm', 'value'), FALSE),
    (1356, 'accm1', 'c', 	oils_i18n_gettext('715', 'Thematic index', 'ccvm', 'value'), FALSE),
    (1357, 'accm1', 'd', 	oils_i18n_gettext('716', 'Libretto or text', 'ccvm', 'value'), FALSE),
    (1358, 'accm1', 'e', 	oils_i18n_gettext('717', 'Biography of composer or author', 'ccvm', 'value'), FALSE),
    (1359, 'accm1', 'f', 	oils_i18n_gettext('718', 'Biography or performer or history of ensemble', 'ccvm', 'value'), FALSE),
    (1360, 'accm1', 'g', 	oils_i18n_gettext('719', 'Technical and/or historical information on instruments', 'ccvm', 'value'), FALSE),
    (1361, 'accm1', 'h', 	oils_i18n_gettext('720', 'Technical information on music', 'ccvm', 'value'), FALSE),
    (1362, 'accm1', 'i', 	oils_i18n_gettext('721', 'Historical information', 'ccvm', 'value'), FALSE),
    (1363, 'accm1', 'k', 	oils_i18n_gettext('722', 'Ethnological information', 'ccvm', 'value'), FALSE),
    (1364, 'accm1', 'r', 	oils_i18n_gettext('723', 'Instructional materials', 'ccvm', 'value'), FALSE),
    (1365, 'accm1', 's', 	oils_i18n_gettext('724', 'Music', 'ccvm', 'value'), FALSE),
    (1366, 'accm1', 'z', 	oils_i18n_gettext('725', 'Other accompanying matter', 'ccvm', 'value'), FALSE),
	
    (1367, 'accm2', 'a', 	oils_i18n_gettext('713', 'Discography', 'ccvm', 'value'), FALSE),
    (1368, 'accm2', 'b', 	oils_i18n_gettext('714', 'Bibliography', 'ccvm', 'value'), FALSE),
    (1369, 'accm2', 'c', 	oils_i18n_gettext('715', 'Thematic index', 'ccvm', 'value'), FALSE),
    (1370, 'accm2', 'd', 	oils_i18n_gettext('716', 'Libretto or text', 'ccvm', 'value'), FALSE),
    (1371, 'accm2', 'e', 	oils_i18n_gettext('717', 'Biography of composer or author', 'ccvm', 'value'), FALSE),
    (1372, 'accm2', 'f', 	oils_i18n_gettext('718', 'Biography or performer or history of ensemble', 'ccvm', 'value'), FALSE),
    (1373, 'accm2', 'g', 	oils_i18n_gettext('719', 'Technical and/or historical information on instruments', 'ccvm', 'value'), FALSE),
    (1374, 'accm2', 'h', 	oils_i18n_gettext('720', 'Technical information on music', 'ccvm', 'value'), FALSE),
    (1375, 'accm2', 'i', 	oils_i18n_gettext('721', 'Historical information', 'ccvm', 'value'), FALSE),
    (1376, 'accm2', 'k', 	oils_i18n_gettext('722', 'Ethnological information', 'ccvm', 'value'), FALSE),
    (1377, 'accm2', 'r', 	oils_i18n_gettext('723', 'Instructional materials', 'ccvm', 'value'), FALSE),
    (1378, 'accm2', 's', 	oils_i18n_gettext('724', 'Music', 'ccvm', 'value'), FALSE),
    (1379, 'accm2', 'z', 	oils_i18n_gettext('725', 'Other accompanying matter', 'ccvm', 'value'), FALSE),
	
    (1380, 'accm3', 'a', 	oils_i18n_gettext('713', 'Discography', 'ccvm', 'value'), FALSE),
    (1381, 'accm3', 'b', 	oils_i18n_gettext('714', 'Bibliography', 'ccvm', 'value'), FALSE),
    (1382, 'accm3', 'c', 	oils_i18n_gettext('715', 'Thematic index', 'ccvm', 'value'), FALSE),
    (1383, 'accm3', 'd', 	oils_i18n_gettext('716', 'Libretto or text', 'ccvm', 'value'), FALSE),
    (1384, 'accm3', 'e', 	oils_i18n_gettext('717', 'Biography of composer or author', 'ccvm', 'value'), FALSE),
    (1385, 'accm3', 'f', 	oils_i18n_gettext('718', 'Biography or performer or history of ensemble', 'ccvm', 'value'), FALSE),
    (1386, 'accm3', 'g', 	oils_i18n_gettext('719', 'Technical and/or historical information on instruments', 'ccvm', 'value'), FALSE),
    (1387, 'accm3', 'h', 	oils_i18n_gettext('720', 'Technical information on music', 'ccvm', 'value'), FALSE),
    (1388, 'accm3', 'i', 	oils_i18n_gettext('721', 'Historical information', 'ccvm', 'value'), FALSE),
    (1389, 'accm3', 'k', 	oils_i18n_gettext('722', 'Ethnological information', 'ccvm', 'value'), FALSE),
    (1390, 'accm3', 'r', 	oils_i18n_gettext('723', 'Instructional materials', 'ccvm', 'value'), FALSE),
    (1391, 'accm3', 's', 	oils_i18n_gettext('724', 'Music', 'ccvm', 'value'), FALSE),
    (1392, 'accm3', 'z', 	oils_i18n_gettext('725', 'Other accompanying matter', 'ccvm', 'value'), FALSE),
	
    (1393, 'accm4', 'a', 	oils_i18n_gettext('713', 'Discography', 'ccvm', 'value'), FALSE),
    (1394, 'accm4', 'b', 	oils_i18n_gettext('714', 'Bibliography', 'ccvm', 'value'), FALSE),
    (1395, 'accm4', 'c', 	oils_i18n_gettext('715', 'Thematic index', 'ccvm', 'value'), FALSE),
    (1396, 'accm4', 'd', 	oils_i18n_gettext('716', 'Libretto or text', 'ccvm', 'value'), FALSE),
    (1397, 'accm4', 'e', 	oils_i18n_gettext('717', 'Biography of composer or author', 'ccvm', 'value'), FALSE),
    (1398, 'accm4', 'f', 	oils_i18n_gettext('718', 'Biography or performer or history of ensemble', 'ccvm', 'value'), FALSE),
    (1399, 'accm4', 'g', 	oils_i18n_gettext('719', 'Technical and/or historical information on instruments', 'ccvm', 'value'), FALSE),
    (1400, 'accm4', 'h', 	oils_i18n_gettext('720', 'Technical information on music', 'ccvm', 'value'), FALSE),
    (1401, 'accm4', 'i', 	oils_i18n_gettext('721', 'Historical information', 'ccvm', 'value'), FALSE),
    (1402, 'accm4', 'k', 	oils_i18n_gettext('722', 'Ethnological information', 'ccvm', 'value'), FALSE),
    (1403, 'accm4', 'r', 	oils_i18n_gettext('723', 'Instructional materials', 'ccvm', 'value'), FALSE),
    (1404, 'accm4', 's', 	oils_i18n_gettext('724', 'Music', 'ccvm', 'value'), FALSE),
    (1405, 'accm4', 'z', 	oils_i18n_gettext('725', 'Other accompanying matter', 'ccvm', 'value'), FALSE),
	
    (1406, 'accm5', 'a', 	oils_i18n_gettext('713', 'Discography', 'ccvm', 'value'), FALSE),
    (1407, 'accm5', 'b', 	oils_i18n_gettext('714', 'Bibliography', 'ccvm', 'value'), FALSE),
    (1408, 'accm5', 'c', 	oils_i18n_gettext('715', 'Thematic index', 'ccvm', 'value'), FALSE),
    (1409, 'accm5', 'd', 	oils_i18n_gettext('716', 'Libretto or text', 'ccvm', 'value'), FALSE),
    (1410, 'accm5', 'e', 	oils_i18n_gettext('717', 'Biography of composer or author', 'ccvm', 'value'), FALSE),
    (1411, 'accm5', 'f', 	oils_i18n_gettext('718', 'Biography or performer or history of ensemble', 'ccvm', 'value'), FALSE),
    (1412, 'accm5', 'g', 	oils_i18n_gettext('719', 'Technical and/or historical information on instruments', 'ccvm', 'value'), FALSE),
    (1413, 'accm5', 'h', 	oils_i18n_gettext('720', 'Technical information on music', 'ccvm', 'value'), FALSE),
    (1414, 'accm5', 'i', 	oils_i18n_gettext('721', 'Historical information', 'ccvm', 'value'), FALSE),
    (1415, 'accm5', 'k', 	oils_i18n_gettext('722', 'Ethnological information', 'ccvm', 'value'), FALSE),
    (1416, 'accm5', 'r', 	oils_i18n_gettext('723', 'Instructional materials', 'ccvm', 'value'), FALSE),
    (1417, 'accm5', 's', 	oils_i18n_gettext('724', 'Music', 'ccvm', 'value'), FALSE),
    (1418, 'accm5', 'z', 	oils_i18n_gettext('725', 'Other accompanying matter', 'ccvm', 'value'), FALSE),
	
    (1419, 'accm6', 'a', 	oils_i18n_gettext('713', 'Discography', 'ccvm', 'value'), FALSE),
    (1420, 'accm6', 'b', 	oils_i18n_gettext('714', 'Bibliography', 'ccvm', 'value'), FALSE),
    (1421, 'accm6', 'c', 	oils_i18n_gettext('715', 'Thematic index', 'ccvm', 'value'), FALSE),
    (1422, 'accm6', 'd', 	oils_i18n_gettext('716', 'Libretto or text', 'ccvm', 'value'), FALSE),
    (1423, 'accm6', 'e', 	oils_i18n_gettext('717', 'Biography of composer or author', 'ccvm', 'value'), FALSE),
    (1424, 'accm6', 'f', 	oils_i18n_gettext('718', 'Biography or performer or history of ensemble', 'ccvm', 'value'), FALSE),
    (1425, 'accm6', 'g', 	oils_i18n_gettext('719', 'Technical and/or historical information on instruments', 'ccvm', 'value'), FALSE),
    (1426, 'accm6', 'h', 	oils_i18n_gettext('720', 'Technical information on music', 'ccvm', 'value'), FALSE),
    (1427, 'accm6', 'i', 	oils_i18n_gettext('721', 'Historical information', 'ccvm', 'value'), FALSE),
    (1428, 'accm6', 'k', 	oils_i18n_gettext('722', 'Ethnological information', 'ccvm', 'value'), FALSE),
    (1429, 'accm6', 'r', 	oils_i18n_gettext('723', 'Instructional materials', 'ccvm', 'value'), FALSE),
    (1430, 'accm6', 's', 	oils_i18n_gettext('724', 'Music', 'ccvm', 'value'), FALSE),
    (1431, 'accm6', 'z', 	oils_i18n_gettext('725', 'Other accompanying matter', 'ccvm', 'value'), FALSE),
	
    (1432, 'cont1', ' ', 	oils_i18n_gettext('835', 'Not specified', 'ccvm', 'value'), FALSE),
    (1433, 'cont1', 'a', 	oils_i18n_gettext('836', 'Abstracts/summaries', 'ccvm', 'value'), FALSE),
    (1434, 'cont1', 'b', 	oils_i18n_gettext('837', 'Bibliographies', 'ccvm', 'value'), FALSE),
    (1435, 'cont1', 'c', 	oils_i18n_gettext('838', 'Catalogs', 'ccvm', 'value'), FALSE),
    (1436, 'cont1', 'd', 	oils_i18n_gettext('839', 'Dictionaries', 'ccvm', 'value'), FALSE),
    (1437, 'cont1', 'e', 	oils_i18n_gettext('840', 'Encyclopedias', 'ccvm', 'value'), FALSE),
    (1438, 'cont1', 'f', 	oils_i18n_gettext('841', 'Handbooks', 'ccvm', 'value'), FALSE),
    (1439, 'cont1', 'g', 	oils_i18n_gettext('842', 'Legal articles', 'ccvm', 'value'), FALSE),
    (1440, 'cont1', 'h', 	oils_i18n_gettext('843', 'Biography', 'ccvm', 'value'), FALSE),
    (1441, 'cont1', 'i', 	oils_i18n_gettext('844', 'Indexes', 'ccvm', 'value'), FALSE),
    (1442, 'cont1', 'j', 	oils_i18n_gettext('845', 'Patent document', 'ccvm', 'value'), FALSE),
    (1443, 'cont1', 'k', 	oils_i18n_gettext('846', 'Discographies', 'ccvm', 'value'), FALSE),
    (1444, 'cont1', 'l', 	oils_i18n_gettext('847', 'Legislation', 'ccvm', 'value'), FALSE),
    (1445, 'cont1', 'm', 	oils_i18n_gettext('848', 'Theses', 'ccvm', 'value'), FALSE),
    (1446, 'cont1', 'n', 	oils_i18n_gettext('849', 'Surveys of the literature in a subject area', 'ccvm', 'value'), FALSE),
    (1447, 'cont1', 'o', 	oils_i18n_gettext('850', 'Reviews', 'ccvm', 'value'), FALSE),
    (1448, 'cont1', 'p', 	oils_i18n_gettext('851', 'Programmed texts', 'ccvm', 'value'), FALSE),
    (1449, 'cont1', 'q', 	oils_i18n_gettext('852', 'Filmographies', 'ccvm', 'value'), FALSE),
    (1450, 'cont1', 'r', 	oils_i18n_gettext('853', 'Directories', 'ccvm', 'value'), FALSE),
    (1451, 'cont1', 's', 	oils_i18n_gettext('854', 'Statistics', 'ccvm', 'value'), FALSE),
    (1452, 'cont1', 't', 	oils_i18n_gettext('855', 'Technical reports', 'ccvm', 'value'), FALSE),
    (1453, 'cont1', 'u', 	oils_i18n_gettext('856', 'Standards/specifications', 'ccvm', 'value'), FALSE),
    (1454, 'cont1', 'v', 	oils_i18n_gettext('857', 'Legal cases and case notes', 'ccvm', 'value'), FALSE),
    (1455, 'cont1', 'w', 	oils_i18n_gettext('858', 'Law reports and digests', 'ccvm', 'value'), FALSE),
    (1456, 'cont1', 'x', 	oils_i18n_gettext('859', 'Other reports', 'ccvm', 'value'), FALSE),
    (1457, 'cont1', 'y', 	oils_i18n_gettext('860', 'Yearbooks', 'ccvm', 'value'), FALSE),
    (1458, 'cont1', 'z', 	oils_i18n_gettext('861', 'Treaties', 'ccvm', 'value'), FALSE),
    (1459, 'cont1', '2', 	oils_i18n_gettext('862', 'Offprints', 'ccvm', 'value'), FALSE),
    (1460, 'cont1', '5', 	oils_i18n_gettext('863', 'Calendars', 'ccvm', 'value'), FALSE),
    (1461, 'cont1', '6', 	oils_i18n_gettext('864', 'Comics/graphic novels', 'ccvm', 'value'), FALSE),
	
    (1462, 'cont2', 'a', 	oils_i18n_gettext('836', 'Abstracts/summaries', 'ccvm', 'value'), FALSE),
    (1463, 'cont2', 'b', 	oils_i18n_gettext('837', 'Bibliographies', 'ccvm', 'value'), FALSE),
    (1464, 'cont2', 'c', 	oils_i18n_gettext('838', 'Catalogs', 'ccvm', 'value'), FALSE),
    (1465, 'cont2', 'd', 	oils_i18n_gettext('839', 'Dictionaries', 'ccvm', 'value'), FALSE),
    (1466, 'cont2', 'e', 	oils_i18n_gettext('840', 'Encyclopedias', 'ccvm', 'value'), FALSE),
    (1467, 'cont2', 'f', 	oils_i18n_gettext('841', 'Handbooks', 'ccvm', 'value'), FALSE),
    (1468, 'cont2', 'g', 	oils_i18n_gettext('842', 'Legal articles', 'ccvm', 'value'), FALSE),
    (1469, 'cont2', 'h', 	oils_i18n_gettext('843', 'Biography', 'ccvm', 'value'), FALSE),
    (1470, 'cont2', 'i', 	oils_i18n_gettext('844', 'Indexes', 'ccvm', 'value'), FALSE),
    (1471, 'cont2', 'j', 	oils_i18n_gettext('845', 'Patent document', 'ccvm', 'value'), FALSE),
    (1472, 'cont2', 'k', 	oils_i18n_gettext('846', 'Discographies', 'ccvm', 'value'), FALSE),
    (1473, 'cont2', 'l', 	oils_i18n_gettext('847', 'Legislation', 'ccvm', 'value'), FALSE),
    (1474, 'cont2', 'm', 	oils_i18n_gettext('848', 'Theses', 'ccvm', 'value'), FALSE),
    (1475, 'cont2', 'n', 	oils_i18n_gettext('849', 'Surveys of the literature in a subject area', 'ccvm', 'value'), FALSE),
    (1476, 'cont2', 'o', 	oils_i18n_gettext('850', 'Reviews', 'ccvm', 'value'), FALSE),
    (1477, 'cont2', 'p', 	oils_i18n_gettext('851', 'Programmed texts', 'ccvm', 'value'), FALSE),
    (1478, 'cont2', 'q', 	oils_i18n_gettext('852', 'Filmographies', 'ccvm', 'value'), FALSE),
    (1479, 'cont2', 'r', 	oils_i18n_gettext('853', 'Directories', 'ccvm', 'value'), FALSE),
    (1480, 'cont2', 's', 	oils_i18n_gettext('854', 'Statistics', 'ccvm', 'value'), FALSE),
    (1481, 'cont2', 't', 	oils_i18n_gettext('855', 'Technical reports', 'ccvm', 'value'), FALSE),
    (1482, 'cont2', 'u', 	oils_i18n_gettext('856', 'Standards/specifications', 'ccvm', 'value'), FALSE),
    (1483, 'cont2', 'v', 	oils_i18n_gettext('857', 'Legal cases and case notes', 'ccvm', 'value'), FALSE),
    (1484, 'cont2', 'w', 	oils_i18n_gettext('858', 'Law reports and digests', 'ccvm', 'value'), FALSE),
    (1485, 'cont2', 'x', 	oils_i18n_gettext('859', 'Other reports', 'ccvm', 'value'), FALSE),
    (1486, 'cont2', 'y', 	oils_i18n_gettext('860', 'Yearbooks', 'ccvm', 'value'), FALSE),
    (1487, 'cont2', 'z', 	oils_i18n_gettext('861', 'Treaties', 'ccvm', 'value'), FALSE),
    (1488, 'cont2', '2', 	oils_i18n_gettext('862', 'Offprints', 'ccvm', 'value'), FALSE),
    (1489, 'cont2', '5', 	oils_i18n_gettext('863', 'Calendars', 'ccvm', 'value'), FALSE),
    (1490, 'cont2', '6', 	oils_i18n_gettext('864', 'Comics/graphic novels', 'ccvm', 'value'), FALSE),
	
    (1491, 'cont3', 'a', 	oils_i18n_gettext('836', 'Abstracts/summaries', 'ccvm', 'value'), FALSE),
    (1492, 'cont3', 'b', 	oils_i18n_gettext('837', 'Bibliographies', 'ccvm', 'value'), FALSE),
    (1493, 'cont3', 'c', 	oils_i18n_gettext('838', 'Catalogs', 'ccvm', 'value'), FALSE),
    (1494, 'cont3', 'd', 	oils_i18n_gettext('839', 'Dictionaries', 'ccvm', 'value'), FALSE),
    (1495, 'cont3', 'e', 	oils_i18n_gettext('840', 'Encyclopedias', 'ccvm', 'value'), FALSE),
    (1496, 'cont3', 'f', 	oils_i18n_gettext('841', 'Handbooks', 'ccvm', 'value'), FALSE),
    (1497, 'cont3', 'g', 	oils_i18n_gettext('842', 'Legal articles', 'ccvm', 'value'), FALSE),
    (1498, 'cont3', 'h', 	oils_i18n_gettext('843', 'Biography', 'ccvm', 'value'), FALSE),
    (1499, 'cont3', 'i', 	oils_i18n_gettext('844', 'Indexes', 'ccvm', 'value'), FALSE),
    (1500, 'cont3', 'j', 	oils_i18n_gettext('845', 'Patent document', 'ccvm', 'value'), FALSE),
    (1501, 'cont3', 'k', 	oils_i18n_gettext('846', 'Discographies', 'ccvm', 'value'), FALSE),
    (1502, 'cont3', 'l', 	oils_i18n_gettext('847', 'Legislation', 'ccvm', 'value'), FALSE),
    (1503, 'cont3', 'm', 	oils_i18n_gettext('848', 'Theses', 'ccvm', 'value'), FALSE),
    (1504, 'cont3', 'n', 	oils_i18n_gettext('849', 'Surveys of the literature in a subject area', 'ccvm', 'value'), FALSE),
    (1505, 'cont3', 'o', 	oils_i18n_gettext('850', 'Reviews', 'ccvm', 'value'), FALSE),
    (1506, 'cont3', 'p', 	oils_i18n_gettext('851', 'Programmed texts', 'ccvm', 'value'), FALSE),
    (1507, 'cont3', 'q', 	oils_i18n_gettext('852', 'Filmographies', 'ccvm', 'value'), FALSE),
    (1508, 'cont3', 'r', 	oils_i18n_gettext('853', 'Directories', 'ccvm', 'value'), FALSE),
    (1509, 'cont3', 's', 	oils_i18n_gettext('854', 'Statistics', 'ccvm', 'value'), FALSE),
    (1510, 'cont3', 't', 	oils_i18n_gettext('855', 'Technical reports', 'ccvm', 'value'), FALSE),
    (1511, 'cont3', 'u', 	oils_i18n_gettext('856', 'Standards/specifications', 'ccvm', 'value'), FALSE),
    (1512, 'cont3', 'v', 	oils_i18n_gettext('857', 'Legal cases and case notes', 'ccvm', 'value'), FALSE),
    (1513, 'cont3', 'w', 	oils_i18n_gettext('858', 'Law reports and digests', 'ccvm', 'value'), FALSE),
    (1514, 'cont3', 'x', 	oils_i18n_gettext('859', 'Other reports', 'ccvm', 'value'), FALSE),
    (1515, 'cont3', 'y', 	oils_i18n_gettext('860', 'Yearbooks', 'ccvm', 'value'), FALSE),
    (1516, 'cont3', 'z', 	oils_i18n_gettext('861', 'Treaties', 'ccvm', 'value'), FALSE),
    (1517, 'cont3', '2', 	oils_i18n_gettext('862', 'Offprints', 'ccvm', 'value'), FALSE),
    (1518, 'cont3', '5', 	oils_i18n_gettext('863', 'Calendars', 'ccvm', 'value'), FALSE),
    (1519, 'cont3', '6', 	oils_i18n_gettext('864', 'Comics/graphic novels', 'ccvm', 'value'), FALSE),
	
    (1520, 'cont4', 'a', 	oils_i18n_gettext('836', 'Abstracts/summaries', 'ccvm', 'value'), FALSE),
    (1521, 'cont4', 'b', 	oils_i18n_gettext('837', 'Bibliographies', 'ccvm', 'value'), FALSE),
    (1522, 'cont4', 'c', 	oils_i18n_gettext('838', 'Catalogs', 'ccvm', 'value'), FALSE),
    (1523, 'cont4', 'd', 	oils_i18n_gettext('839', 'Dictionaries', 'ccvm', 'value'), FALSE),
    (1524, 'cont4', 'e', 	oils_i18n_gettext('840', 'Encyclopedias', 'ccvm', 'value'), FALSE),
    (1525, 'cont4', 'f', 	oils_i18n_gettext('841', 'Handbooks', 'ccvm', 'value'), FALSE),
    (1526, 'cont4', 'g', 	oils_i18n_gettext('842', 'Legal articles', 'ccvm', 'value'), FALSE),
    (1527, 'cont4', 'h', 	oils_i18n_gettext('843', 'Biography', 'ccvm', 'value'), FALSE),
    (1528, 'cont4', 'i', 	oils_i18n_gettext('844', 'Indexes', 'ccvm', 'value'), FALSE),
    (1529, 'cont4', 'j', 	oils_i18n_gettext('845', 'Patent document', 'ccvm', 'value'), FALSE),
    (1530, 'cont4', 'k', 	oils_i18n_gettext('846', 'Discographies', 'ccvm', 'value'), FALSE),
    (1531, 'cont4', 'l', 	oils_i18n_gettext('847', 'Legislation', 'ccvm', 'value'), FALSE),
    (1532, 'cont4', 'm', 	oils_i18n_gettext('848', 'Theses', 'ccvm', 'value'), FALSE),
    (1533, 'cont4', 'n', 	oils_i18n_gettext('849', 'Surveys of the literature in a subject area', 'ccvm', 'value'), FALSE),
    (1534, 'cont4', 'o', 	oils_i18n_gettext('850', 'Reviews', 'ccvm', 'value'), FALSE),
    (1535, 'cont4', 'p', 	oils_i18n_gettext('851', 'Programmed texts', 'ccvm', 'value'), FALSE),
    (1536, 'cont4', 'q', 	oils_i18n_gettext('852', 'Filmographies', 'ccvm', 'value'), FALSE),
    (1537, 'cont4', 'r', 	oils_i18n_gettext('853', 'Directories', 'ccvm', 'value'), FALSE),
    (1538, 'cont4', 's', 	oils_i18n_gettext('854', 'Statistics', 'ccvm', 'value'), FALSE),
    (1539, 'cont4', 't', 	oils_i18n_gettext('855', 'Technical reports', 'ccvm', 'value'), FALSE),
    (1540, 'cont4', 'u', 	oils_i18n_gettext('856', 'Standards/specifications', 'ccvm', 'value'), FALSE),
    (1541, 'cont4', 'v', 	oils_i18n_gettext('857', 'Legal cases and case notes', 'ccvm', 'value'), FALSE),
    (1542, 'cont4', 'w', 	oils_i18n_gettext('858', 'Law reports and digests', 'ccvm', 'value'), FALSE),
    (1543, 'cont4', 'x', 	oils_i18n_gettext('859', 'Other reports', 'ccvm', 'value'), FALSE),
    (1544, 'cont4', 'y', 	oils_i18n_gettext('860', 'Yearbooks', 'ccvm', 'value'), FALSE),
    (1545, 'cont4', 'z', 	oils_i18n_gettext('861', 'Treaties', 'ccvm', 'value'), FALSE),
    (1546, 'cont4', '2', 	oils_i18n_gettext('862', 'Offprints', 'ccvm', 'value'), FALSE),
    (1547, 'cont4', '5', 	oils_i18n_gettext('863', 'Calendars', 'ccvm', 'value'), FALSE),
    (1548, 'cont4', '6', 	oils_i18n_gettext('864', 'Comics/graphic novels', 'ccvm', 'value'), FALSE),
	
    (1549, 'ltxt1', ' ', 	oils_i18n_gettext('881', 'Item is a music sound recording', 'ccvm', 'value'), FALSE),
    (1550, 'ltxt1', 'a', 	oils_i18n_gettext('882', 'Autobiography', 'ccvm', 'value'), FALSE),
    (1551, 'ltxt1', 'b', 	oils_i18n_gettext('883', 'Biography', 'ccvm', 'value'), FALSE),
    (1552, 'ltxt1', 'c', 	oils_i18n_gettext('884', 'Conference proceedings', 'ccvm', 'value'), FALSE),
    (1553, 'ltxt1', 'd', 	oils_i18n_gettext('885', 'Drama', 'ccvm', 'value'), FALSE),
    (1554, 'ltxt1', 'e', 	oils_i18n_gettext('886', 'Essays', 'ccvm', 'value'), FALSE),
    (1555, 'ltxt1', 'f', 	oils_i18n_gettext('887', 'Fiction', 'ccvm', 'value'), FALSE),
    (1556, 'ltxt1', 'g', 	oils_i18n_gettext('888', 'Reporting', 'ccvm', 'value'), FALSE),
    (1557, 'ltxt1', 'h', 	oils_i18n_gettext('889', 'History', 'ccvm', 'value'), FALSE),
    (1558, 'ltxt1', 'i', 	oils_i18n_gettext('890', 'Instruction', 'ccvm', 'value'), FALSE),
    (1559, 'ltxt1', 'j', 	oils_i18n_gettext('891', 'Language instruction', 'ccvm', 'value'), FALSE),
    (1560, 'ltxt1', 'k', 	oils_i18n_gettext('892', 'Comedy', 'ccvm', 'value'), FALSE),
    (1561, 'ltxt1', 'l', 	oils_i18n_gettext('893', 'Lectures, speeches', 'ccvm', 'value'), FALSE),
    (1562, 'ltxt1', 'm', 	oils_i18n_gettext('894', 'Memoirs', 'ccvm', 'value'), FALSE),
    (1563, 'ltxt1', 'n', 	oils_i18n_gettext('895', 'Not applicable', 'ccvm', 'value'), FALSE),
    (1564, 'ltxt1', 'o', 	oils_i18n_gettext('896', 'Folktales', 'ccvm', 'value'), FALSE),
    (1565, 'ltxt1', 'p', 	oils_i18n_gettext('897', 'Poetry', 'ccvm', 'value'), FALSE),
    (1566, 'ltxt1', 'r', 	oils_i18n_gettext('898', 'Rehearsals', 'ccvm', 'value'), FALSE),
    (1567, 'ltxt1', 's', 	oils_i18n_gettext('899', 'Sounds', 'ccvm', 'value'), FALSE),
    (1568, 'ltxt1', 't', 	oils_i18n_gettext('900', 'Interviews', 'ccvm', 'value'), FALSE),
    (1569, 'ltxt1', 'z', 	oils_i18n_gettext('901', 'Other', 'ccvm', 'value'), FALSE),
	
    (1570, 'ltxt2', 'a', 	oils_i18n_gettext('882', 'Autobiography', 'ccvm', 'value'), FALSE),
    (1571, 'ltxt2', 'b', 	oils_i18n_gettext('883', 'Biography', 'ccvm', 'value'), FALSE),
    (1572, 'ltxt2', 'c', 	oils_i18n_gettext('884', 'Conference proceedings', 'ccvm', 'value'), FALSE),
    (1573, 'ltxt2', 'd', 	oils_i18n_gettext('885', 'Drama', 'ccvm', 'value'), FALSE),
    (1574, 'ltxt2', 'e', 	oils_i18n_gettext('886', 'Essays', 'ccvm', 'value'), FALSE),
    (1575, 'ltxt2', 'f', 	oils_i18n_gettext('887', 'Fiction', 'ccvm', 'value'), FALSE),
    (1576, 'ltxt2', 'g', 	oils_i18n_gettext('888', 'Reporting', 'ccvm', 'value'), FALSE),
    (1577, 'ltxt2', 'h', 	oils_i18n_gettext('889', 'History', 'ccvm', 'value'), FALSE),
    (1578, 'ltxt2', 'i', 	oils_i18n_gettext('890', 'Instruction', 'ccvm', 'value'), FALSE),
    (1579, 'ltxt2', 'j', 	oils_i18n_gettext('891', 'Language instruction', 'ccvm', 'value'), FALSE),
    (1580, 'ltxt2', 'k', 	oils_i18n_gettext('892', 'Comedy', 'ccvm', 'value'), FALSE),
    (1581, 'ltxt2', 'l', 	oils_i18n_gettext('893', 'Lectures, speeches', 'ccvm', 'value'), FALSE),
    (1582, 'ltxt2', 'm', 	oils_i18n_gettext('894', 'Memoirs', 'ccvm', 'value'), FALSE),
    (1583, 'ltxt2', 'n', 	oils_i18n_gettext('895', 'Not applicable', 'ccvm', 'value'), FALSE),
    (1584, 'ltxt2', 'o', 	oils_i18n_gettext('896', 'Folktales', 'ccvm', 'value'), FALSE),
    (1585, 'ltxt2', 'p', 	oils_i18n_gettext('897', 'Poetry', 'ccvm', 'value'), FALSE),
    (1586, 'ltxt2', 'r', 	oils_i18n_gettext('898', 'Rehearsals', 'ccvm', 'value'), FALSE),
    (1587, 'ltxt2', 's', 	oils_i18n_gettext('899', 'Sounds', 'ccvm', 'value'), FALSE),
    (1588, 'ltxt2', 't', 	oils_i18n_gettext('900', 'Interviews', 'ccvm', 'value'), FALSE),
    (1589, 'ltxt2', 'z', 	oils_i18n_gettext('901', 'Other', 'ccvm', 'value'), FALSE),
	
    (1590, 'relf1', ' ', 	oils_i18n_gettext('965', 'No relief shown', 'ccvm', 'value'), FALSE),
    (1591, 'relf1', 'a', 	oils_i18n_gettext('966', 'Contours', 'ccvm', 'value'), FALSE),
    (1592, 'relf1', 'b', 	oils_i18n_gettext('967', 'Shading', 'ccvm', 'value'), FALSE),
    (1593, 'relf1', 'c', 	oils_i18n_gettext('968', 'Gradient and bathymetric tints', 'ccvm', 'value'), FALSE),
    (1594, 'relf1', 'd', 	oils_i18n_gettext('969', 'Hachures', 'ccvm', 'value'), FALSE),
    (1595, 'relf1', 'e', 	oils_i18n_gettext('970', 'Bathymetry, soundings', 'ccvm', 'value'), FALSE),
    (1596, 'relf1', 'f', 	oils_i18n_gettext('971', 'Form lines', 'ccvm', 'value'), FALSE),
    (1597, 'relf1', 'g', 	oils_i18n_gettext('972', 'Spot heights', 'ccvm', 'value'), FALSE),
    (1598, 'relf1', 'i', 	oils_i18n_gettext('973', 'Pictorially', 'ccvm', 'value'), FALSE),
    (1599, 'relf1', 'j', 	oils_i18n_gettext('974', 'Land forms', 'ccvm', 'value'), FALSE),
    (1600, 'relf1', 'k', 	oils_i18n_gettext('975', 'Bathymetry, isolines', 'ccvm', 'value'), FALSE),
    (1601, 'relf1', 'm', 	oils_i18n_gettext('976', 'Rock drawings', 'ccvm', 'value'), FALSE),
    (1602, 'relf1', 'z', 	oils_i18n_gettext('977', 'Other', 'ccvm', 'value'), FALSE),
	
    (1603, 'relf2', 'a', 	oils_i18n_gettext('966', 'Contours', 'ccvm', 'value'), FALSE),
    (1604, 'relf2', 'b', 	oils_i18n_gettext('967', 'Shading', 'ccvm', 'value'), FALSE),
    (1605, 'relf2', 'c', 	oils_i18n_gettext('968', 'Gradient and bathymetric tints', 'ccvm', 'value'), FALSE),
    (1606, 'relf2', 'd', 	oils_i18n_gettext('969', 'Hachures', 'ccvm', 'value'), FALSE),
    (1607, 'relf2', 'e', 	oils_i18n_gettext('970', 'Bathymetry, soundings', 'ccvm', 'value'), FALSE),
    (1608, 'relf2', 'f', 	oils_i18n_gettext('971', 'Form lines', 'ccvm', 'value'), FALSE),
    (1609, 'relf2', 'g', 	oils_i18n_gettext('972', 'Spot heights', 'ccvm', 'value'), FALSE),
    (1610, 'relf2', 'i', 	oils_i18n_gettext('973', 'Pictorially', 'ccvm', 'value'), FALSE),
    (1611, 'relf2', 'j', 	oils_i18n_gettext('974', 'Land forms', 'ccvm', 'value'), FALSE),
    (1612, 'relf2', 'k', 	oils_i18n_gettext('975', 'Bathymetry, isolines', 'ccvm', 'value'), FALSE),
    (1613, 'relf2', 'm', 	oils_i18n_gettext('976', 'Rock drawings', 'ccvm', 'value'), FALSE),
    (1614, 'relf2', 'z', 	oils_i18n_gettext('977', 'Other', 'ccvm', 'value'), FALSE),
	
    (1615, 'relf3', 'a', 	oils_i18n_gettext('966', 'Contours', 'ccvm', 'value'), FALSE),
    (1616, 'relf3', 'b', 	oils_i18n_gettext('967', 'Shading', 'ccvm', 'value'), FALSE),
    (1617, 'relf3', 'c', 	oils_i18n_gettext('968', 'Gradient and bathymetric tints', 'ccvm', 'value'), FALSE),
    (1618, 'relf3', 'd', 	oils_i18n_gettext('969', 'Hachures', 'ccvm', 'value'), FALSE),
    (1619, 'relf3', 'e', 	oils_i18n_gettext('970', 'Bathymetry, soundings', 'ccvm', 'value'), FALSE),
    (1620, 'relf3', 'f', 	oils_i18n_gettext('971', 'Form lines', 'ccvm', 'value'), FALSE),
    (1621, 'relf3', 'g', 	oils_i18n_gettext('972', 'Spot heights', 'ccvm', 'value'), FALSE),
    (1622, 'relf3', 'i', 	oils_i18n_gettext('973', 'Pictorially', 'ccvm', 'value'), FALSE),
    (1623, 'relf3', 'j', 	oils_i18n_gettext('974', 'Land forms', 'ccvm', 'value'), FALSE),
    (1624, 'relf3', 'k', 	oils_i18n_gettext('975', 'Bathymetry, isolines', 'ccvm', 'value'), FALSE),
    (1625, 'relf3', 'm', 	oils_i18n_gettext('976', 'Rock drawings', 'ccvm', 'value'), FALSE),
    (1626, 'relf3', 'z', 	oils_i18n_gettext('977', 'Other', 'ccvm', 'value'), FALSE),
	
    (1627, 'relf4', 'a', 	oils_i18n_gettext('966', 'Contours', 'ccvm', 'value'), FALSE),
    (1628, 'relf4', 'b', 	oils_i18n_gettext('967', 'Shading', 'ccvm', 'value'), FALSE),
    (1629, 'relf4', 'c', 	oils_i18n_gettext('968', 'Gradient and bathymetric tints', 'ccvm', 'value'), FALSE),
    (1630, 'relf4', 'd', 	oils_i18n_gettext('969', 'Hachures', 'ccvm', 'value'), FALSE),
    (1631, 'relf4', 'e', 	oils_i18n_gettext('970', 'Bathymetry, soundings', 'ccvm', 'value'), FALSE),
    (1632, 'relf4', 'f', 	oils_i18n_gettext('971', 'Form lines', 'ccvm', 'value'), FALSE),
    (1633, 'relf4', 'g', 	oils_i18n_gettext('972', 'Spot heights', 'ccvm', 'value'), FALSE),
    (1634, 'relf4', 'i', 	oils_i18n_gettext('973', 'Pictorially', 'ccvm', 'value'), FALSE),
    (1635, 'relf4', 'j', 	oils_i18n_gettext('974', 'Land forms', 'ccvm', 'value'), FALSE),
    (1636, 'relf4', 'k', 	oils_i18n_gettext('975', 'Bathymetry, isolines', 'ccvm', 'value'), FALSE),
    (1637, 'relf4', 'm', 	oils_i18n_gettext('976', 'Rock drawings', 'ccvm', 'value'), FALSE),
    (1638, 'relf4', 'z', 	oils_i18n_gettext('977', 'Other', 'ccvm', 'value'), FALSE),
	
    (1639, 'spfm1', ' ', 	oils_i18n_gettext('978', 'No specified special format characteristics', 'ccvm', 'value'), FALSE),
    (1640, 'spfm1', 'e', 	oils_i18n_gettext('979', 'Manuscript', 'ccvm', 'value'), FALSE),
    (1641, 'spfm1', 'j', 	oils_i18n_gettext('980', 'Picture card, post card', 'ccvm', 'value'), FALSE),
    (1642, 'spfm1', 'k', 	oils_i18n_gettext('981', 'Calendar', 'ccvm', 'value'), FALSE),
    (1643, 'spfm1', 'l', 	oils_i18n_gettext('982', 'Puzzle', 'ccvm', 'value'), FALSE),
    (1644, 'spfm1', 'n', 	oils_i18n_gettext('983', 'Game', 'ccvm', 'value'), FALSE),
    (1645, 'spfm1', 'o', 	oils_i18n_gettext('984', 'Wall map', 'ccvm', 'value'), FALSE),
    (1646, 'spfm1', 'p', 	oils_i18n_gettext('985', 'Playing cards', 'ccvm', 'value'), FALSE),
    (1647, 'spfm1', 'r', 	oils_i18n_gettext('986', 'Loose-leaf', 'ccvm', 'value'), FALSE),
    (1648, 'spfm1', 'z', 	oils_i18n_gettext('987', 'Other', 'ccvm', 'value'), FALSE),
	
    (1649, 'spfm2', 'e', 	oils_i18n_gettext('979', 'Manuscript', 'ccvm', 'value'), FALSE),
    (1650, 'spfm2', 'j', 	oils_i18n_gettext('980', 'Picture card, post card', 'ccvm', 'value'), FALSE),
    (1651, 'spfm2', 'k', 	oils_i18n_gettext('981', 'Calendar', 'ccvm', 'value'), FALSE),
    (1652, 'spfm2', 'l', 	oils_i18n_gettext('982', 'Puzzle', 'ccvm', 'value'), FALSE),
    (1653, 'spfm2', 'n', 	oils_i18n_gettext('983', 'Game', 'ccvm', 'value'), FALSE),
    (1654, 'spfm2', 'o', 	oils_i18n_gettext('984', 'Wall map', 'ccvm', 'value'), FALSE),
    (1655, 'spfm2', 'p', 	oils_i18n_gettext('985', 'Playing cards', 'ccvm', 'value'), FALSE),
    (1656, 'spfm2', 'r', 	oils_i18n_gettext('986', 'Loose-leaf', 'ccvm', 'value'), FALSE),
    (1657, 'spfm2', 'z', 	oils_i18n_gettext('987', 'Other', 'ccvm', 'value'), FALSE),
	
    (1658, 'ills', ' ', 	oils_i18n_gettext('1658', 'No Illustrations', 'ccvm', 'value'), FALSE),
    (1659, 'ills', 'a', 	oils_i18n_gettext('1659', 'Illustrations', 'ccvm', 'value'), FALSE),
    (1660, 'ills', 'b', 	oils_i18n_gettext('1660', 'Maps', 'ccvm', 'value'), FALSE),
    (1661, 'ills', 'c', 	oils_i18n_gettext('1661', 'Portraits', 'ccvm', 'value'), FALSE),
    (1662, 'ills', 'd', 	oils_i18n_gettext('1662', 'Charts', 'ccvm', 'value'), FALSE),
    (1663, 'ills', 'e', 	oils_i18n_gettext('1663', 'Plans', 'ccvm', 'value'), FALSE),
    (1664, 'ills', 'f', 	oils_i18n_gettext('1664', 'Plates', 'ccvm', 'value'), FALSE),
    (1665, 'ills', 'g', 	oils_i18n_gettext('1665', 'Music', 'ccvm', 'value'), FALSE),
    (1666, 'ills', 'h', 	oils_i18n_gettext('1666', 'Facsimiles', 'ccvm', 'value'), FALSE),
    (1667, 'ills', 'i', 	oils_i18n_gettext('1667', 'Coats of arms', 'ccvm', 'value'), FALSE),
    (1668, 'ills', 'j', 	oils_i18n_gettext('1668', 'Genealogical tables', 'ccvm', 'value'), FALSE),
    (1669, 'ills', 'k', 	oils_i18n_gettext('1669', 'Forms', 'ccvm', 'value'), FALSE),
    (1670, 'ills', 'l', 	oils_i18n_gettext('1670', 'Samples', 'ccvm', 'value'), FALSE),
    (1671, 'ills', 'm', 	oils_i18n_gettext('1671', 'Phonodisc, phonowire, etc.', 'ccvm', 'value'), FALSE),
    (1672, 'ills', 'o', 	oils_i18n_gettext('1672', 'Photographs', 'ccvm', 'value'), FALSE),
    (1673, 'ills', 'p', 	oils_i18n_gettext('1673', 'Illuminations', 'ccvm', 'value'), FALSE),
	
    (1674, 'ills1', ' ', 	oils_i18n_gettext('1658', 'No Illustrations', 'ccvm', 'value'), FALSE),
    (1675, 'ills1', 'a', 	oils_i18n_gettext('1659', 'Illustrations', 'ccvm', 'value'), FALSE),
    (1676, 'ills1', 'b', 	oils_i18n_gettext('1660', 'Maps', 'ccvm', 'value'), FALSE),
    (1677, 'ills1', 'c', 	oils_i18n_gettext('1661', 'Portraits', 'ccvm', 'value'), FALSE),
    (1678, 'ills1', 'd', 	oils_i18n_gettext('1662', 'Charts', 'ccvm', 'value'), FALSE),
    (1679, 'ills1', 'e', 	oils_i18n_gettext('1663', 'Plans', 'ccvm', 'value'), FALSE),
    (1680, 'ills1', 'f', 	oils_i18n_gettext('1664', 'Plates', 'ccvm', 'value'), FALSE),
    (1681, 'ills1', 'g', 	oils_i18n_gettext('1665', 'Music', 'ccvm', 'value'), FALSE),
    (1682, 'ills1', 'h', 	oils_i18n_gettext('1666', 'Facsimiles', 'ccvm', 'value'), FALSE),
    (1683, 'ills1', 'i', 	oils_i18n_gettext('1667', 'Coats of arms', 'ccvm', 'value'), FALSE),
    (1684, 'ills1', 'j', 	oils_i18n_gettext('1668', 'Genealogical tables', 'ccvm', 'value'), FALSE),
    (1685, 'ills1', 'k', 	oils_i18n_gettext('1669', 'Forms', 'ccvm', 'value'), FALSE),
    (1686, 'ills1', 'l', 	oils_i18n_gettext('1670', 'Samples', 'ccvm', 'value'), FALSE),
    (1687, 'ills1', 'm', 	oils_i18n_gettext('1671', 'Phonodisc, phonowire, etc.', 'ccvm', 'value'), FALSE),
    (1688, 'ills1', 'o', 	oils_i18n_gettext('1672', 'Photographs', 'ccvm', 'value'), FALSE),
    (1689, 'ills1', 'p', 	oils_i18n_gettext('1673', 'Illuminations', 'ccvm', 'value'), FALSE),
	
    (1690, 'ills2', 'a', 	oils_i18n_gettext('1659', 'Illustrations', 'ccvm', 'value'), FALSE),
    (1691, 'ills2', 'b', 	oils_i18n_gettext('1660', 'Maps', 'ccvm', 'value'), FALSE),
    (1692, 'ills2', 'c', 	oils_i18n_gettext('1661', 'Portraits', 'ccvm', 'value'), FALSE),
    (1693, 'ills2', 'd', 	oils_i18n_gettext('1662', 'Charts', 'ccvm', 'value'), FALSE),
    (1694, 'ills2', 'e', 	oils_i18n_gettext('1663', 'Plans', 'ccvm', 'value'), FALSE),
    (1695, 'ills2', 'f', 	oils_i18n_gettext('1664', 'Plates', 'ccvm', 'value'), FALSE),
    (1696, 'ills2', 'g', 	oils_i18n_gettext('1665', 'Music', 'ccvm', 'value'), FALSE),
    (1697, 'ills2', 'h', 	oils_i18n_gettext('1666', 'Facsimiles', 'ccvm', 'value'), FALSE),
    (1698, 'ills2', 'i', 	oils_i18n_gettext('1667', 'Coats of arms', 'ccvm', 'value'), FALSE),
    (1699, 'ills2', 'j', 	oils_i18n_gettext('1668', 'Genealogical tables', 'ccvm', 'value'), FALSE),
    (1700, 'ills2', 'k', 	oils_i18n_gettext('1669', 'Forms', 'ccvm', 'value'), FALSE),
    (1701, 'ills2', 'l', 	oils_i18n_gettext('1670', 'Samples', 'ccvm', 'value'), FALSE),
    (1702, 'ills2', 'm', 	oils_i18n_gettext('1671', 'Phonodisc, phonowire, etc.', 'ccvm', 'value'), FALSE),
    (1703, 'ills2', 'o', 	oils_i18n_gettext('1672', 'Photographs', 'ccvm', 'value'), FALSE),
    (1704, 'ills2', 'p', 	oils_i18n_gettext('1673', 'Illuminations', 'ccvm', 'value'), FALSE),
	
    (1705, 'ills3', 'a', 	oils_i18n_gettext('1659', 'Illustrations', 'ccvm', 'value'), FALSE),
    (1706, 'ills3', 'b', 	oils_i18n_gettext('1660', 'Maps', 'ccvm', 'value'), FALSE),
    (1707, 'ills3', 'c', 	oils_i18n_gettext('1661', 'Portraits', 'ccvm', 'value'), FALSE),
    (1708, 'ills3', 'd', 	oils_i18n_gettext('1662', 'Charts', 'ccvm', 'value'), FALSE),
    (1709, 'ills3', 'e', 	oils_i18n_gettext('1663', 'Plans', 'ccvm', 'value'), FALSE),
    (1710, 'ills3', 'f', 	oils_i18n_gettext('1664', 'Plates', 'ccvm', 'value'), FALSE),
    (1711, 'ills3', 'g', 	oils_i18n_gettext('1665', 'Music', 'ccvm', 'value'), FALSE),
    (1712, 'ills3', 'h', 	oils_i18n_gettext('1666', 'Facsimiles', 'ccvm', 'value'), FALSE),
    (1713, 'ills3', 'i', 	oils_i18n_gettext('1667', 'Coats of arms', 'ccvm', 'value'), FALSE),
    (1714, 'ills3', 'j', 	oils_i18n_gettext('1668', 'Genealogical tables', 'ccvm', 'value'), FALSE),
    (1715, 'ills3', 'k', 	oils_i18n_gettext('1669', 'Forms', 'ccvm', 'value'), FALSE),
    (1716, 'ills3', 'l', 	oils_i18n_gettext('1670', 'Samples', 'ccvm', 'value'), FALSE),
    (1717, 'ills3', 'm', 	oils_i18n_gettext('1671', 'Phonodisc, phonowire, etc.', 'ccvm', 'value'), FALSE),
    (1718, 'ills3', 'o', 	oils_i18n_gettext('1672', 'Photographs', 'ccvm', 'value'), FALSE),
    (1719, 'ills3', 'p', 	oils_i18n_gettext('1673', 'Illuminations', 'ccvm', 'value'), FALSE),
	
    (1720, 'ills4', 'a', 	oils_i18n_gettext('1659', 'Illustrations', 'ccvm', 'value'), FALSE),
    (1721, 'ills4', 'b', 	oils_i18n_gettext('1660', 'Maps', 'ccvm', 'value'), FALSE),
    (1722, 'ills4', 'c', 	oils_i18n_gettext('1661', 'Portraits', 'ccvm', 'value'), FALSE),
    (1723, 'ills4', 'd', 	oils_i18n_gettext('1662', 'Charts', 'ccvm', 'value'), FALSE),
    (1724, 'ills4', 'e', 	oils_i18n_gettext('1663', 'Plans', 'ccvm', 'value'), FALSE),
    (1725, 'ills4', 'f', 	oils_i18n_gettext('1664', 'Plates', 'ccvm', 'value'), FALSE),
    (1726, 'ills4', 'g', 	oils_i18n_gettext('1665', 'Music', 'ccvm', 'value'), FALSE),
    (1727, 'ills4', 'h', 	oils_i18n_gettext('1666', 'Facsimiles', 'ccvm', 'value'), FALSE),
    (1728, 'ills4', 'i', 	oils_i18n_gettext('1667', 'Coats of arms', 'ccvm', 'value'), FALSE),
    (1729, 'ills4', 'j', 	oils_i18n_gettext('1668', 'Genealogical tables', 'ccvm', 'value'), FALSE),
    (1730, 'ills4', 'k', 	oils_i18n_gettext('1669', 'Forms', 'ccvm', 'value'), FALSE),
    (1731, 'ills4', 'l', 	oils_i18n_gettext('1670', 'Samples', 'ccvm', 'value'), FALSE),
    (1732, 'ills4', 'm', 	oils_i18n_gettext('1671', 'Phonodisc, phonowire, etc.', 'ccvm', 'value'), FALSE),
    (1733, 'ills4', 'o', 	oils_i18n_gettext('1672', 'Photographs', 'ccvm', 'value'), FALSE),
    (1734, 'ills4', 'p', 	oils_i18n_gettext('1673', 'Illuminations', 'ccvm', 'value'), FALSE);
	

-- Composite coded value maps, this way the "primary" fixed field can be used in advanced searches without a ton of ORs and extra work.
-- Space is used as a filler for any position other than the first, so for something to actually have "No accompanying matter," for example, specifically accm1 must = ' '.
-- Any other value has the same meaning in any position.
INSERT INTO config.composite_attr_entry_definition (coded_value, definition) VALUES
    (1735, '{"_attr":"accm1","_val":" "}'),
    (713, '[{"_attr":"accm6","_val":"a"},{"_attr":"accm5","_val":"a"},{"_attr":"accm4","_val":"a"},{"_attr":"accm3","_val":"a"},{"_attr":"accm2","_val":"a"},{"_attr":"accm1","_val":"a"}]'),
    (714, '[{"_attr":"accm6","_val":"b"},{"_attr":"accm5","_val":"b"},{"_attr":"accm4","_val":"b"},{"_attr":"accm3","_val":"b"},{"_attr":"accm2","_val":"b"},{"_attr":"accm1","_val":"b"}]'),
    (715, '[{"_attr":"accm6","_val":"c"},{"_attr":"accm5","_val":"c"},{"_attr":"accm4","_val":"c"},{"_attr":"accm3","_val":"c"},{"_attr":"accm2","_val":"c"},{"_attr":"accm1","_val":"c"}]'),
    (716, '[{"_attr":"accm6","_val":"d"},{"_attr":"accm5","_val":"d"},{"_attr":"accm4","_val":"d"},{"_attr":"accm3","_val":"d"},{"_attr":"accm2","_val":"d"},{"_attr":"accm1","_val":"d"}]'),
    (717, '[{"_attr":"accm6","_val":"e"},{"_attr":"accm5","_val":"e"},{"_attr":"accm4","_val":"e"},{"_attr":"accm3","_val":"e"},{"_attr":"accm2","_val":"e"},{"_attr":"accm1","_val":"e"}]'),
    (718, '[{"_attr":"accm6","_val":"f"},{"_attr":"accm5","_val":"f"},{"_attr":"accm4","_val":"f"},{"_attr":"accm3","_val":"f"},{"_attr":"accm2","_val":"f"},{"_attr":"accm1","_val":"f"}]'),
    (719, '[{"_attr":"accm6","_val":"g"},{"_attr":"accm5","_val":"g"},{"_attr":"accm4","_val":"g"},{"_attr":"accm3","_val":"g"},{"_attr":"accm2","_val":"g"},{"_attr":"accm1","_val":"g"}]'),
    (720, '[{"_attr":"accm6","_val":"h"},{"_attr":"accm5","_val":"h"},{"_attr":"accm4","_val":"h"},{"_attr":"accm3","_val":"h"},{"_attr":"accm2","_val":"h"},{"_attr":"accm1","_val":"h"}]'),
    (721, '[{"_attr":"accm6","_val":"i"},{"_attr":"accm5","_val":"i"},{"_attr":"accm4","_val":"i"},{"_attr":"accm3","_val":"i"},{"_attr":"accm2","_val":"i"},{"_attr":"accm1","_val":"i"}]'),
    (722, '[{"_attr":"accm6","_val":"k"},{"_attr":"accm5","_val":"k"},{"_attr":"accm4","_val":"k"},{"_attr":"accm3","_val":"k"},{"_attr":"accm2","_val":"k"},{"_attr":"accm1","_val":"k"}]'),
    (723, '[{"_attr":"accm6","_val":"r"},{"_attr":"accm5","_val":"r"},{"_attr":"accm4","_val":"r"},{"_attr":"accm3","_val":"r"},{"_attr":"accm2","_val":"r"},{"_attr":"accm1","_val":"r"}]'),
    (724, '[{"_attr":"accm6","_val":"s"},{"_attr":"accm5","_val":"s"},{"_attr":"accm4","_val":"s"},{"_attr":"accm3","_val":"s"},{"_attr":"accm2","_val":"s"},{"_attr":"accm1","_val":"s"}]'),
    (725, '[{"_attr":"accm6","_val":"z"},{"_attr":"accm5","_val":"z"},{"_attr":"accm4","_val":"z"},{"_attr":"accm3","_val":"z"},{"_attr":"accm2","_val":"z"},{"_attr":"accm1","_val":"z"}]'),

    (835, '{"_attr":"cont1","_val":" "}'),
    (836, '[{"_attr":"cont4","_val":"a"},{"_attr":"cont3","_val":"a"},{"_attr":"cont2","_val":"a"},{"_attr":"cont1","_val":"a"}]'),
    (837, '[{"_attr":"cont4","_val":"b"},{"_attr":"cont3","_val":"b"},{"_attr":"cont2","_val":"b"},{"_attr":"cont1","_val":"b"}]'),
    (838, '[{"_attr":"cont4","_val":"c"},{"_attr":"cont3","_val":"c"},{"_attr":"cont2","_val":"c"},{"_attr":"cont1","_val":"c"}]'),
    (839, '[{"_attr":"cont4","_val":"d"},{"_attr":"cont3","_val":"d"},{"_attr":"cont2","_val":"d"},{"_attr":"cont1","_val":"d"}]'),
    (840, '[{"_attr":"cont4","_val":"e"},{"_attr":"cont3","_val":"e"},{"_attr":"cont2","_val":"e"},{"_attr":"cont1","_val":"e"}]'),
    (841, '[{"_attr":"cont4","_val":"f"},{"_attr":"cont3","_val":"f"},{"_attr":"cont2","_val":"f"},{"_attr":"cont1","_val":"f"}]'),
    (842, '[{"_attr":"cont4","_val":"g"},{"_attr":"cont3","_val":"g"},{"_attr":"cont2","_val":"g"},{"_attr":"cont1","_val":"g"}]'),
    (843, '[{"_attr":"cont4","_val":"h"},{"_attr":"cont3","_val":"h"},{"_attr":"cont2","_val":"h"},{"_attr":"cont1","_val":"h"}]'),
    (844, '[{"_attr":"cont4","_val":"i"},{"_attr":"cont3","_val":"i"},{"_attr":"cont2","_val":"i"},{"_attr":"cont1","_val":"i"}]'),
    (845, '[{"_attr":"cont4","_val":"j"},{"_attr":"cont3","_val":"j"},{"_attr":"cont2","_val":"j"},{"_attr":"cont1","_val":"j"}]'),
    (846, '[{"_attr":"cont4","_val":"k"},{"_attr":"cont3","_val":"k"},{"_attr":"cont2","_val":"k"},{"_attr":"cont1","_val":"k"}]'),
    (847, '[{"_attr":"cont4","_val":"l"},{"_attr":"cont3","_val":"l"},{"_attr":"cont2","_val":"l"},{"_attr":"cont1","_val":"l"}]'),
    (848, '[{"_attr":"cont4","_val":"m"},{"_attr":"cont3","_val":"m"},{"_attr":"cont2","_val":"m"},{"_attr":"cont1","_val":"m"}]'),
    (849, '[{"_attr":"cont4","_val":"n"},{"_attr":"cont3","_val":"n"},{"_attr":"cont2","_val":"n"},{"_attr":"cont1","_val":"n"}]'),
    (850, '[{"_attr":"cont4","_val":"o"},{"_attr":"cont3","_val":"o"},{"_attr":"cont2","_val":"o"},{"_attr":"cont1","_val":"o"}]'),
    (851, '[{"_attr":"cont4","_val":"p"},{"_attr":"cont3","_val":"p"},{"_attr":"cont2","_val":"p"},{"_attr":"cont1","_val":"p"}]'),
    (852, '[{"_attr":"cont4","_val":"q"},{"_attr":"cont3","_val":"q"},{"_attr":"cont2","_val":"q"},{"_attr":"cont1","_val":"q"}]'),
    (853, '[{"_attr":"cont4","_val":"r"},{"_attr":"cont3","_val":"r"},{"_attr":"cont2","_val":"r"},{"_attr":"cont1","_val":"r"}]'),
    (854, '[{"_attr":"cont4","_val":"s"},{"_attr":"cont3","_val":"s"},{"_attr":"cont2","_val":"s"},{"_attr":"cont1","_val":"s"}]'),
    (855, '[{"_attr":"cont4","_val":"t"},{"_attr":"cont3","_val":"t"},{"_attr":"cont2","_val":"t"},{"_attr":"cont1","_val":"t"}]'),
    (856, '[{"_attr":"cont4","_val":"u"},{"_attr":"cont3","_val":"u"},{"_attr":"cont2","_val":"u"},{"_attr":"cont1","_val":"u"}]'),
    (857, '[{"_attr":"cont4","_val":"v"},{"_attr":"cont3","_val":"v"},{"_attr":"cont2","_val":"v"},{"_attr":"cont1","_val":"v"}]'),
    (858, '[{"_attr":"cont4","_val":"w"},{"_attr":"cont3","_val":"w"},{"_attr":"cont2","_val":"w"},{"_attr":"cont1","_val":"w"}]'),
    (859, '[{"_attr":"cont4","_val":"x"},{"_attr":"cont3","_val":"x"},{"_attr":"cont2","_val":"x"},{"_attr":"cont1","_val":"x"}]'),
    (860, '[{"_attr":"cont4","_val":"y"},{"_attr":"cont3","_val":"y"},{"_attr":"cont2","_val":"y"},{"_attr":"cont1","_val":"y"}]'),
    (861, '[{"_attr":"cont4","_val":"z"},{"_attr":"cont3","_val":"z"},{"_attr":"cont2","_val":"z"},{"_attr":"cont1","_val":"z"}]'),
    (862, '[{"_attr":"cont4","_val":"2"},{"_attr":"cont3","_val":"2"},{"_attr":"cont2","_val":"2"},{"_attr":"cont1","_val":"2"}]'),
    (863, '[{"_attr":"cont4","_val":"5"},{"_attr":"cont3","_val":"5"},{"_attr":"cont2","_val":"5"},{"_attr":"cont1","_val":"5"}]'),
    (864, '[{"_attr":"cont4","_val":"6"},{"_attr":"cont3","_val":"6"},{"_attr":"cont2","_val":"6"},{"_attr":"cont1","_val":"6"}]'),

    (881, '{"_attr":"ltxt1","_val":" "}'),
    (882, '[{"_attr":"ltxt2","_val":"a"},{"_attr":"ltxt1","_val":"a"}]'),
    (883, '[{"_attr":"ltxt2","_val":"b"},{"_attr":"ltxt1","_val":"b"}]'),
    (884, '[{"_attr":"ltxt2","_val":"c"},{"_attr":"ltxt1","_val":"c"}]'),
    (885, '[{"_attr":"ltxt2","_val":"d"},{"_attr":"ltxt1","_val":"d"}]'),
    (886, '[{"_attr":"ltxt2","_val":"e"},{"_attr":"ltxt1","_val":"e"}]'),
    (887, '[{"_attr":"ltxt2","_val":"f"},{"_attr":"ltxt1","_val":"f"}]'),
    (888, '[{"_attr":"ltxt2","_val":"g"},{"_attr":"ltxt1","_val":"g"}]'),
    (889, '[{"_attr":"ltxt2","_val":"h"},{"_attr":"ltxt1","_val":"h"}]'),
    (890, '[{"_attr":"ltxt2","_val":"i"},{"_attr":"ltxt1","_val":"i"}]'),
    (891, '[{"_attr":"ltxt2","_val":"j"},{"_attr":"ltxt1","_val":"j"}]'),
    (892, '[{"_attr":"ltxt2","_val":"k"},{"_attr":"ltxt1","_val":"k"}]'),
    (893, '[{"_attr":"ltxt2","_val":"l"},{"_attr":"ltxt1","_val":"l"}]'),
    (894, '[{"_attr":"ltxt2","_val":"m"},{"_attr":"ltxt1","_val":"m"}]'),
    (895, '[{"_attr":"ltxt2","_val":"n"},{"_attr":"ltxt1","_val":"n"}]'),
    (896, '[{"_attr":"ltxt2","_val":"o"},{"_attr":"ltxt1","_val":"o"}]'),
    (897, '[{"_attr":"ltxt2","_val":"p"},{"_attr":"ltxt1","_val":"p"}]'),
    (898, '[{"_attr":"ltxt2","_val":"r"},{"_attr":"ltxt1","_val":"r"}]'),
    (899, '[{"_attr":"ltxt2","_val":"s"},{"_attr":"ltxt1","_val":"s"}]'),
    (900, '[{"_attr":"ltxt2","_val":"t"},{"_attr":"ltxt1","_val":"t"}]'),
    (901, '[{"_attr":"ltxt2","_val":"z"},{"_attr":"ltxt1","_val":"z"}]'),

    (965, '{"_attr":"relf1","_val":" "}'),
    (966, '[{"_attr":"relf4","_val":"a"},{"_attr":"relf3","_val":"a"},{"_attr":"relf2","_val":"a"},{"_attr":"relf1","_val":"a"}]'),
    (967, '[{"_attr":"relf4","_val":"b"},{"_attr":"relf3","_val":"b"},{"_attr":"relf2","_val":"b"},{"_attr":"relf1","_val":"b"}]'),
    (968, '[{"_attr":"relf4","_val":"c"},{"_attr":"relf3","_val":"c"},{"_attr":"relf2","_val":"c"},{"_attr":"relf1","_val":"c"}]'),
    (969, '[{"_attr":"relf4","_val":"d"},{"_attr":"relf3","_val":"d"},{"_attr":"relf2","_val":"d"},{"_attr":"relf1","_val":"d"}]'),
    (970, '[{"_attr":"relf4","_val":"e"},{"_attr":"relf3","_val":"e"},{"_attr":"relf2","_val":"e"},{"_attr":"relf1","_val":"e"}]'),
    (971, '[{"_attr":"relf4","_val":"f"},{"_attr":"relf3","_val":"f"},{"_attr":"relf2","_val":"f"},{"_attr":"relf1","_val":"f"}]'),
    (972, '[{"_attr":"relf4","_val":"g"},{"_attr":"relf3","_val":"g"},{"_attr":"relf2","_val":"g"},{"_attr":"relf1","_val":"g"}]'),
    (973, '[{"_attr":"relf4","_val":"i"},{"_attr":"relf3","_val":"i"},{"_attr":"relf2","_val":"i"},{"_attr":"relf1","_val":"i"}]'),
    (974, '[{"_attr":"relf4","_val":"j"},{"_attr":"relf3","_val":"j"},{"_attr":"relf2","_val":"j"},{"_attr":"relf1","_val":"j"}]'),
    (975, '[{"_attr":"relf4","_val":"k"},{"_attr":"relf3","_val":"k"},{"_attr":"relf2","_val":"k"},{"_attr":"relf1","_val":"k"}]'),
    (976, '[{"_attr":"relf4","_val":"m"},{"_attr":"relf3","_val":"m"},{"_attr":"relf2","_val":"m"},{"_attr":"relf1","_val":"m"}]'),
    (977, '[{"_attr":"relf4","_val":"z"},{"_attr":"relf3","_val":"z"},{"_attr":"relf2","_val":"z"},{"_attr":"relf1","_val":"z"}]'),

    (978, '{"_attr":"spfm1","_val":" "}'),
    (979, '[{"_attr":"spfm2","_val":"e"},{"_attr":"spfm1","_val":"e"}]'),
    (980, '[{"_attr":"spfm2","_val":"j"},{"_attr":"spfm1","_val":"j"}]'),
    (981, '[{"_attr":"spfm2","_val":"k"},{"_attr":"spfm1","_val":"k"}]'),
    (982, '[{"_attr":"spfm2","_val":"l"},{"_attr":"spfm1","_val":"l"}]'),
    (983, '[{"_attr":"spfm2","_val":"n"},{"_attr":"spfm1","_val":"n"}]'),
    (984, '[{"_attr":"spfm2","_val":"o"},{"_attr":"spfm1","_val":"o"}]'),
    (985, '[{"_attr":"spfm2","_val":"p"},{"_attr":"spfm1","_val":"p"}]'),
    (986, '[{"_attr":"spfm2","_val":"r"},{"_attr":"spfm1","_val":"r"}]'),
    (987, '[{"_attr":"spfm2","_val":"z"},{"_attr":"spfm1","_val":"z"}]'),
	
    (1658, '{"_attr":"ills1","_val":" "}'),
    (1659, '[{"_attr":"ills4","_val":"a"},{"_attr":"ills3","_val":"a"},{"_attr":"ills2","_val":"a"},{"_attr":"ills1","_val":"a"}]'),
    (1660, '[{"_attr":"ills4","_val":"b"},{"_attr":"ills3","_val":"b"},{"_attr":"ills2","_val":"b"},{"_attr":"ills1","_val":"b"}]'),
    (1661, '[{"_attr":"ills4","_val":"c"},{"_attr":"ills3","_val":"c"},{"_attr":"ills2","_val":"c"},{"_attr":"ills1","_val":"c"}]'),
    (1662, '[{"_attr":"ills4","_val":"d"},{"_attr":"ills3","_val":"d"},{"_attr":"ills2","_val":"d"},{"_attr":"ills1","_val":"d"}]'),
    (1663, '[{"_attr":"ills4","_val":"e"},{"_attr":"ills3","_val":"e"},{"_attr":"ills2","_val":"e"},{"_attr":"ills1","_val":"e"}]'),
    (1664, '[{"_attr":"ills4","_val":"f"},{"_attr":"ills3","_val":"f"},{"_attr":"ills2","_val":"f"},{"_attr":"ills1","_val":"f"}]'),
    (1665, '[{"_attr":"ills4","_val":"g"},{"_attr":"ills3","_val":"g"},{"_attr":"ills2","_val":"g"},{"_attr":"ills1","_val":"g"}]'),
    (1666, '[{"_attr":"ills4","_val":"h"},{"_attr":"ills3","_val":"h"},{"_attr":"ills2","_val":"h"},{"_attr":"ills1","_val":"h"}]'),
    (1667, '[{"_attr":"ills4","_val":"i"},{"_attr":"ills3","_val":"i"},{"_attr":"ills2","_val":"i"},{"_attr":"ills1","_val":"i"}]'),
    (1668, '[{"_attr":"ills4","_val":"j"},{"_attr":"ills3","_val":"j"},{"_attr":"ills2","_val":"j"},{"_attr":"ills1","_val":"j"}]'),
    (1669, '[{"_attr":"ills4","_val":"k"},{"_attr":"ills3","_val":"k"},{"_attr":"ills2","_val":"k"},{"_attr":"ills1","_val":"k"}]'),
    (1670, '[{"_attr":"ills4","_val":"l"},{"_attr":"ills3","_val":"l"},{"_attr":"ills2","_val":"l"},{"_attr":"ills1","_val":"l"}]'),
    (1671, '[{"_attr":"ills4","_val":"m"},{"_attr":"ills3","_val":"m"},{"_attr":"ills2","_val":"m"},{"_attr":"ills1","_val":"m"}]'),
    (1672, '[{"_attr":"ills4","_val":"o"},{"_attr":"ills3","_val":"o"},{"_attr":"ills2","_val":"o"},{"_attr":"ills1","_val":"o"}]'),
    (1673, '[{"_attr":"ills4","_val":"p"},{"_attr":"ills3","_val":"p"},{"_attr":"ills2","_val":"p"},{"_attr":"ills1","_val":"p"}]');

SELECT evergreen.upgrade_deps_block_check('0968', :eg_version); -- jstompro/gmcharlt

--create hook for actor.usr.create_date
INSERT INTO action_trigger.hook (key, core_type, description, passive)
    VALUES ('au.created', 'au', 'A user was created', 't');
	
--SQL to create event definition for new account creation notice
--Inactive, owned by top of org tree by default.  Modify to suit needs.

INSERT INTO action_trigger.event_definition (
    active, owner, name, hook, 
    validator, reactor, delay, delay_field,
    max_delay, template
)  VALUES (
    'f', '1', 'New User Created Welcome Notice', 'au.created',
    'NOOP_True', 'SendEmail', '10 seconds', 'create_date',
    '1 day',
$$
[%- USE date -%]
[%- user = target -%]
[%- lib = target.home_ou -%]
To: [%- params.recipient_email || user.email %]
From: [%- helpers.get_org_setting(target.home_ou.id, 'org.bounced_emails') || lib.email || params.sender_email || default_sender %]
Reply-To: [%- helpers.get_org_setting(target.home_ou.id, 'org.bounced_emails') || lib.email || params.sender_email || default_sender %]
Subject: New Library Account Sign-up - Welcome!
Auto-Submitted: auto-generated

Dear [% user.first_given_name %] [% user.family_name %],

Thank you for signing up for an account with the [% lib.name %] on [% user.create_date.substr(0, 10) %].

This email is your confirmation that your account is set up and ready as well as testing to see that we have your correct email address.

If you did not sign up for an account at the library and have received this email in error, please reply and let us know.

You can access your account online at http://catalog/eg/opac/login. From that site you can search the catalog, request materials, renew materials, leave comments, leave suggestions for titles you would like the library to purchase and update your account information.

Sincerely,
[% lib.name %]

Contact your library for more information:

[% lib.name %]
[%- SET addr = lib.mailing_address -%]
[%- IF !addr -%] [%- SET addr = lib.billing_address -%] [%- END %]
[% addr.street1 %] [% addr.street2 %]
[% addr.city %], [% addr.state %]
[% addr.post_code %]
[% lib.phone %]
[% lib.email %]

$$);
	
--insert environment values
INSERT INTO action_trigger.environment (event_def, path) VALUES
    (CURRVAL('action_trigger.event_definition_id_seq'), 'home_ou.mailing_address'),
    (CURRVAL('action_trigger.event_definition_id_seq'), 'home_ou.billing_address');
	
SELECT evergreen.upgrade_deps_block_check('0969', :eg_version); -- jeffdavis/stompro

INSERT INTO config.org_unit_setting_type
    (name, grp, label, description, datatype)
    VALUES
        ('org.restrict_opt_to_depth',
         'sec',
         oils_i18n_gettext('org.restrict_opt_to_depth',
            'Restrict patron opt-in to home library and related orgs at specified depth',
            'coust', 'label'),
         oils_i18n_gettext('org.restrict_opt_to_depth',
            'Patrons at this library can only be opted-in at org units which are within the '||
            'library''s section of the org tree, at or below the depth specified by this setting. '||
            'They cannot be opted in at any other libraries.',
            'coust', 'description'),
        'integer');

SELECT evergreen.upgrade_deps_block_check('0970', :eg_version); -- Dyrcona/gmcharlt

CREATE OR REPLACE FUNCTION search.facets_for_record_set(ignore_facet_classes TEXT[], hits BIGINT[]) RETURNS TABLE (id INT, value TEXT, count BIGINT) AS $$
    SELECT id, value, count FROM (
        SELECT mfae.field AS id,
               mfae.value,
               COUNT(DISTINCT mmrsm.source),
               row_number() OVER (
                PARTITION BY mfae.field ORDER BY COUNT(distinct mmrsm.source) DESC
               ) AS rownum
        FROM metabib.facet_entry mfae
        JOIN metabib.metarecord_source_map mmrsm ON (mfae.source = mmrsm.source)
        JOIN config.metabib_field cmf ON (cmf.id = mfae.field)
        WHERE mmrsm.source IN (SELECT * FROM unnest($2))
        AND cmf.facet_field
        AND cmf.field_class NOT IN (SELECT * FROM unnest($1))
        GROUP by 1, 2
    ) all_facets
    WHERE rownum <= (SELECT COALESCE((SELECT value::INT FROM config.global_flag WHERE name = 'search.max_facets_per_field' AND enabled), 1000));
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION search.facets_for_metarecord_set(ignore_facet_classes TEXT[], hits BIGINT[]) RETURNS TABLE (id INT, value TEXT, count BIGINT) AS $$
    SELECT id, value, count FROM (
        SELECT mfae.field AS id,
               mfae.value,
               COUNT(DISTINCT mmrsm.metarecord),
               row_number() OVER (
                PARTITION BY mfae.field ORDER BY COUNT(distinct mmrsm.metarecord) DESC
               ) AS rownum
        FROM metabib.facet_entry mfae
        JOIN metabib.metarecord_source_map mmrsm ON (mfae.source = mmrsm.source)
        JOIN config.metabib_field cmf ON (cmf.id = mfae.field)
        WHERE mmrsm.metarecord IN (SELECT * FROM unnest($2))
        AND cmf.facet_field
        AND cmf.field_class NOT IN (SELECT * FROM unnest($1))
        GROUP by 1, 2
    ) all_facets
    WHERE rownum <= (SELECT COALESCE((SELECT value::INT FROM config.global_flag WHERE name = 'search.max_facets_per_field' AND enabled), 1000));
$$ LANGUAGE SQL;

COMMIT;

-- The following updates/inserts are allowed to fail

INSERT INTO config.index_normalizer (name, description, func, param_count) VALUES (
        'Number or NULL Normalize',
        'Normalize the value to NULL if it is not a number',
        'integer_or_null',
        0
);

INSERT INTO config.index_normalizer (name, description, func, param_count) VALUES (
        'Approximate Low Date Normalize',
        'Normalize the value to the nearest date-ish value, rounding down',
        'approximate_low_date',
        0
);

INSERT INTO config.index_normalizer (name, description, func, param_count) VALUES (
        'Approximate High Date Normalize',
        'Normalize the value to the nearest date-ish value, rounding up',
        'approximate_high_date',
        0
);

INSERT INTO config.record_attr_index_norm_map (attr,norm,pos)
    SELECT  m.name, i.id, 0
      FROM  config.record_attr_definition m,
            config.index_normalizer i
      WHERE i.func IN ('integer_or_null')
            AND m.name IN ('date2', 'pubdate');

INSERT INTO config.record_attr_index_norm_map (attr,norm,pos)
    SELECT  m.name, i.id, 0
      FROM  config.record_attr_definition m,
            config.index_normalizer i
      WHERE i.func IN ('approximate_low_date')
            AND m.name IN ('date1');

INSERT INTO config.record_attr_index_norm_map (attr,norm,pos)
    SELECT  m.name, i.id, 0
      FROM  config.record_attr_definition m,
            config.index_normalizer i
      WHERE i.func IN ('approximate_high_date')
            AND m.name IN ('date2');

-- Get rid of bad date1 sorter values so we can avoid a reingest
DELETE FROM metabib.record_sorter WHERE attr = 'pubdate' AND value !~ '^\d+$';

-- and these are reingests that are allowed be interrupted
\qecho
\qecho To use the new identifier|genre index, it is necessary to do
\qecho a partial reingest of records that have a 655 tag. You can
\qecho cancel out of this if you wish and run this and the following
\qecho attribute reingest later.
\qecho
SELECT metabib.reingest_metabib_field_entries(record, FALSE, TRUE, FALSE)
FROM metabib.real_full_rec
WHERE tag IN ('655')
GROUP BY record;

\qecho
\qecho This is a record attribute reingest of your bib records.
\qecho It will take a while.
\qecho You may cancel now without losing the effect of the rest of the
\qecho upgrade script, and arrange the reingest later.
SELECT COUNT(metabib.reingest_record_attributes(id))
    FROM biblio.record_entry WHERE deleted IS FALSE;
