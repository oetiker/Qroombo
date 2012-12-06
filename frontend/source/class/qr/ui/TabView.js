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
    construct : function(table) {
        var model = new qr.data.RemoteTableModel(table);
        var cfg = qr.data.Config.getInstance();
        var tabView = cfg.getTabView(table);
        var that = this;
        model.setColumns(tabView.labels.map(function(item){
            return that.tr(item)
        }), tabView.fields);                                                     
        this.base(arguments, model, tabView.widths);
    }
});
