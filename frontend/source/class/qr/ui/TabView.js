/* ************************************************************************

   Copyrigtht: OETIKER+PARTNER AG
   License:    GPLv3 or later
   Authors:    Tobias Oetiker
   Utf8Check:  äöü

************************************************************************ */

/**
 * Create a table with the given table model and relative column widths.
 */
qx.Class.define("qr.ui.TabView", {
    extend : qr.ui.Table,

    /**
     * @param table {String} name of the server side table object
     * @param widths {Array} relative column widths
     */
    construct : function(tableKey) {
        var model = new qr.data.RemoteTableModel(tableKey);
        this._tableKey = tableKey;
        var cfg = qr.data.Config.getInstance();
        var tabView = cfg.getTabView(tableKey);
        var that = this;
        model.setColumns(tabView.labels.map(function(item){
            return that['tr'](item)
        }), tabView.fields);                        
        this.base(arguments, model, tabView.widths);
        this.addListener('appear',function(){
	    this.reloadData();
        },this);
    },
    members: {
        _tableKey: null,
        reloadData: function(){
	    this.getTableModel().reloadData();
        },
        getSelectedRecId: function(){
            var sm = this.getSelectionModel();
            var tm = this.getTableModel();
            var recId;
            sm.iterateSelection(function(ind) {
                recId = tm.getRowData(ind)[this._tableKey + '_id'];
            },this);
            return recId;
        }
    }
});
