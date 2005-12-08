dump('Loading constants.js\n');
var api = {
	'auth_init' : { 'app' : 'open-ils.auth', 'method' : 'open-ils.auth.authenticate.init' },
	'auth_complete' : { 'app' : 'open-ils.auth', 'method' : 'open-ils.auth.authenticate.complete' },
	'blob_checkouts_retrieve' : { 'app' : 'open-ils.circ', 'method' : 'open-ils.circ.actor.user.checked_out' },
	'checkout_permit_via_barcode' : { 'app' : 'open-ils.circ', 'method' : 'open-ils.circ.permit_checkout' },
	'checkout_via_barcode' : { 'app' : 'open-ils.circ', 'method' : 'open-ils.circ.checkout.barcode' },
	'fm_acpl_retrieve' : { 'app' : 'open-ils.search', 'method' : 'open-ils.search.config.copy_location.retrieve.all' },
	'fm_actsc_retrieve_via_aou' : { 'app' : 'open-ils.circ', 'method' : 'open-ils.circ.stat_cat.actor.retrieve.all' },
	'fm_ahr_retrieve' : { 'app' : 'open-ils.circ', 'method' : 'open-ils.circ.holds.retrieve' },
	'fm_aou_retrieve' : { 'app' : 'open-ils.actor', 'method' : 'open-ils.actor.org_tree.retrieve' },
	'fm_aou_retrieve_related_via_session' : { 'app' : 'open-ils.actor', 'method' : 'open-ils.actor.org_unit.full_path.retrieve' },
	'fm_aout_retrieve' : { 'app' : 'open-ils.actor', 'method' : 'open-ils.actor.org_types.retrieve' },
	'fm_au_retrieve_via_session' : { 'app' : 'open-ils.search', 'method' : 'open-ils.search.actor.user.session' },
	'fm_au_retrieve_via_barcode' : { 'app' : 'open-ils.actor', 'method' : 'open-ils.actor.user.fleshed.retrieve_by_barcode' },
	'fm_ccs_retrieve' : { 'app' : 'open-ils.search', 'method' : 'open-ils.search.config.copy_status.retrieve.all' },
	'fm_cit_retrieve' : { 'app' : 'open-ils.actor', 'method' : 'open-ils.actor.user.ident_types.retrieve' },
	'fm_cst_retrieve' : { 'app' : 'open-ils.actor', 'method' : 'open-ils.actor.standings.retrieve' },
	'fm_mobts_having_balance' : { 'app' : 'open-ils.actor', 'method' : 'open-ils.actor.user.transactions.have_balance' },
	'fm_pgt_retrieve' : { 'app' : 'open-ils.actor', 'method' : 'open-ils.actor.groups.retrieve' }
}

var urls = {
	'opac' : 'http://dev.gapines.org/',
	'remote_checkout' : '/xul/server/circ/checkout.xul',
	'remote_menu_frame' : '/xul/server/main/menu_frame.xul',
	'remote_patron_barcode_entry' : '/xul/server/patron/barcode_entry.xul',
	'remote_patron_display' : '/xul/server/patron/display.xul'
}
