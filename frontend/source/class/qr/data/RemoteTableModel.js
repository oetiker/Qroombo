/* ************************************************************************
   Copyrigtht: OETIKER+PARTNER AG
   License:    GPL V3 or later
   Authors:    Tobias Oetiker
   Utf8Check:  äöü
************************************************************************ */

/**
 * An {@link qx.ui.table.model.Remote} implementation for accessing
 * accessing the node cache on the server.
 */
qx.Class.define('qr.data.RemoteTableModel', {
    extend : qx.ui.table.model.Remote,


    /**
     * Create an instance of the remote table model.
     */
    construct : function(view) {
        this.base(arguments);
        this.__view = view;
    },

    properties : {
        /**
         * when set to null no records show
         */
        search : {
            nullable : true,
            apply    : '_applySearch'
        }
    },

    members : {
        __view : null,


        /**
         * Provid our implementation to make remote table work
         *
         */
        _loadRowCount : function() {
            var rpc = qr.data.Server.getInstance();
            var that = this;
            that._onRowCountLoaded(5);
        },

        /*            rpc.callAsync(function(ret, exc) {
                        if (exc) {
                            qr.ui.MsgBox.getInstance().exc(exc);
                            ret = 0;
                        }
        
                        // call this even when we had issues from
                        // remote. without it the remote table gets its
                        // undies in a twist.
                        that._onRowCountLoaded(ret);
                    },
                    'getRowCount', this.__view,this.getSearch());
        */

        /**
         * Reload the table data when the search string changes
         *
         * @param newValue {Integer} New TagId
         * @param oldValue {Integer} Old TagId
         */
        _applySearch : function(newValue, oldValue) {
            if (newValue != oldValue) {
                this.reloadData();
            }
        },


        /**
         * Provide our own implementation of the row data loader.
         *
         * @param firstRow {Integer} first row to load
         * @param lastRow {Integer} last row to load
         */
        _loadRowData : function(firstRow, lastRow) {
            var rpc = qr.data.Server.getInstance();
            var that = this;
            that._onRowDataLoaded({});
        }
    }
});

/*            
            rpc.callAsync(function(ret, exc) {
                if (exc) {
                    qr.ui.MsgBox.getInstance().exc(exc);
                    ret = {};
                }

                // call this even when we had issues from
                // remote. without it the remote table gets its
                // undies in a twist.
                that._onRowDataLoaded(ret);
            },
            'getRows', this.__view, this.getSearch(), lastRow - firstRow + 1, firstRow);
*/