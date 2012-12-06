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
        var cfg = qr.data.Config.getInstance();
        cfg.addListener('changeAddrId',function(){        
            this.reloadData();
        },this);
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
            var cfg = qr.data.Config.getInstance();
            if (cfg.getUserId() == null){
                this._onRowCountLoaded(0);
                return;
            }
            var rpc = qr.data.Server.getInstance();
            var that = this;
            rpc.callAsync(function(ret, exc) {
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
        },


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
            var cfg = qr.data.Config.getInstance();
            if (cfg.getUserId() == null){
                that._onRowDataLoaded([]);
                return;
            }
            var sortCol = this.getColumnId(this.getSortColumnIndex());
            var sortAsc = this.isSortAscending();
            var rpc = qr.data.Server.getInstance();
            var that = this;            
            rpc.callAsync(function(ret, exc) {
                if (exc) {
                    qr.ui.MsgBox.getInstance().exc(exc);
                    ret = [];
                }
                // call this even when we had issues from
                // remote. without it the remote table gets its
                // undies in a twist.
                that._onRowDataLoaded(ret);
            },
            'getRows', this.__view, this.getSearch(), lastRow - firstRow + 1, firstRow,sortCol,sortAsc);
        }
    }
});
