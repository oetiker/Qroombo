/* ************************************************************************

   Copyrigtht: OETIKER+PARTNER AG
   License:    GPLv3 or later
   Authors:    Tobias Oetiker
   Utf8Check:  äöü

************************************************************************ */

/**
 * Create a table with the given table model and relative column widths.
 */
qx.Class.define("qr.ui.Table", {
    extend : qx.ui.table.Table,
    /**
     * @param tm {qx.ui.table.Model} table model
     * @param widths {Array} relative column widths
     */
    construct : function(tm, widths) {
        var tableOpts = {
            tableColumnModel : function(obj) {
                return new qx.ui.table.columnmodel.Resize(obj);
            }
        };

        this.base(arguments, tm, tableOpts);
        this.set({ 
            showCellFocusIndicator : false,
            statusBarVisible: false 
        });
        
        // hide the first column as it contains the internal
        // id of the node
        var tcm = this.getTableColumnModel();
        if (widths) {
            var resizeBehavior = tcm.getBehavior();

            for (var i=0; i<widths.length; i++) {
                resizeBehavior.setWidth(i, String(widths[i]) + "*");
            }
        }

        this.getDataRowRenderer().setHighlightFocusRow(false);
    }
});
