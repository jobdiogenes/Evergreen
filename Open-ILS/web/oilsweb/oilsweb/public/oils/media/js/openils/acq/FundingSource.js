if(!dojo._hasResource['openils.acq.FundingSource']) {
dojo._hasResource['openils.acq.FundingSource'] = true;
dojo.provide('openils.acq.FundingSource');
dojo.require('util.Dojo');

/** Declare the FundingSource class with dojo */
dojo.declare('openils.acq.FundingSource', null, {
    /* add instance methods here if necessary */
});

/** cached funding_source objects */
openils.acq.FundingSource.cache = {};

openils.acq.FundingSource.createStore = function(onComplete) {
    /** Fetches the list of funding_sources and builds a grid from them */
    var ses = new OpenSRF.ClientSession('open-ils.acq');
    var req = ses.request('open-ils.acq.funding_source.org.retrieve', 
        oilsAuthtoken, null, {flesh_summary:1});

    req.oncomplete = function(r) {
        var msg
        var items = [];
        var src = null;
        while(msg = r.recv()) {
            src = msg.content();
            openils.acq.FundingSource.cache[src.id()] = src;
            items.push(src);
        }
        onComplete(acqfs.toStoreData(items));
    };

    req.send();
};



/**
 * Create a new funding source object
 * @param fields Key/value pairs used to create the new funding source
 */
openils.acq.FundingSource.create = function(fields, onCreateComplete) {

    var fs = new acqfs()
    for(var field in fields) 
        fs[field](fields[field]);

    var ses = new OpenSRF.ClientSession('open-ils.acq');
    var req = ses.request('open-ils.acq.funding_source.create', oilsAuthtoken, fs);

    req.oncomplete = function(r) {
        var msg = r.recv();
        var id = msg.content();
        if(onCreateComplete)
            onCreateComplete(id);
    };
    req.send();
};


openils.acq.FundingSource.createCredit = function(fields, onCreateComplete) {

    var fsc = new acqfscred()
    for(var field in fields) 
        fsc[field](fields[field]);

    var ses = new OpenSRF.ClientSession('open-ils.acq');
    var req = ses.request(
        'open-ils.acq.funding_source_credit.create', oilsAuthtoken, fsc);

    req.oncomplete = function(r) {
        var msg = r.recv();
        var id = msg.content();
        if(onCreateComplete)
            onCreateComplete(id);
    };
    req.send();
};


openils.acq.FundingSource.deleteFromGrid = function(grid, onComplete) {
    var list = []
    var selected = grid.selection.getSelected();
    for(var rowIdx in selected) 
        list.push(grid.model.getDatum(selected[rowIdx], 0));
    openils.acq.FundingSource.deleteList(list, onComplete);
};

openils.acq.FundingSource.deleteList = function(list, onComplete) {
    openils.acq.FundingSource._deleteList(list, 0, onComplete);
}

openils.acq.FundingSource._deleteList = function(list, idx, onComplete) {
    if(idx >= list.length)    
        return onComplete();

    var ses = new OpenSRF.ClientSession('open-ils.acq');
    var req = ses.request('open-ils.acq.funding_source.delete', oilsAuthtoken, list[idx]);
    delete openils.acq.FundingSource.cache[list[idx]];

    req.oncomplete = function(r) {
        msg = r.recv()
        stat = msg.content();
        /* XXX CHECH FOR EVENT */
        openils.acq.FundingSource._deleteList(list, ++idx, onComplete);
    }
    req.send();
};


} /* end dojo._hasResource[] */
