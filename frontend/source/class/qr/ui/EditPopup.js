/* ************************************************************************
   Copyright: 2012 OETIKER+PARTNER AG
   License:   GPLv3 or later
   Authors:   Tobi Oetiker <tobi@oetiker.ch>
   Utf8Check: äöü
************************************************************************ */

/*
#asset(qx/icon/${qx.icontheme}/22/actions/dialog-close.png)
#asset(qx/icon/${qx.icontheme}/22/actions/dialog-cancel.png)
#asset(qx/icon/${qx.icontheme}/22/actions/dialog-ok.png)
*/

/**
  * get details on booking
  */
qx.Class.define("qr.ui.EditPopup", {
    extend : qx.ui.window.Window,

    construct : function(tableKey,title) {
        this.base(arguments,title);

        this.set({
            allowClose    : true,
            allowMaximize : false,
            allowMinimize : false,
            showClose     : true,
            showMaximize  : false,
            showMinimize  : false,
            showStatusbar : false,
            width         : 400,
            layout        : new qx.ui.layout.VBox(15),
            modal         : true
        });

        var cfg = this._cfg = qr.data.Config.getInstance();

        this._tableKey = tableKey;

        this.addListener('appear', function() {
            this.center();
        }, this);

        this._updateForm();
        this._populateForm();
    },

    properties : {
        recId : {
            event : 'changeRecId',
            init  : null,
            nullable: true
        }
    },

    events : { changeForm : 'qx.event.type.Event' },

    members : {
        _cfg : null,
        _form : null,
        _tableKey : null,

        /**
         * TODOC
         *
         * @param recId|valueMap {var} 
         */
        show : function(rec) {            
            if (!this._form) {
                this.addListenerOnce('changeForm', function(){this.show(rec)}, this);
                return;
            }
            
            if (qx.lang.Type.isObject(rec)){
                this.setRecId(null);
                this._form.setData(rec, true); /* only set fields that are available */
            }
            else {
                this.setRecId(rec);
            }
            this.base(arguments);  
        },


        /**
         * TODOC
         *
         * @param e {Event} TODOC
         */
        _updateForm : function(e) {

            /* skip if the addr id did not really change */

            var that = this;
            this.setEnabled(false);

            if (that._form) {
                that.remove(that._form);
                that._form.dispose();
                that._form = null;
            }

            var rpc = qr.data.Server.getInstance();

            rpc.callAsyncSmart(function(form) {
                that._form = new qr.ui.AutoForm(form, new qx.ui.layout.VBox(5));
                that.addAt(that._form, 0);
                that.setEnabled(true);
                var hold = false;
                that.fireEvent('changeForm');
            }, 'getForm', this._tableKey);
        },


        _populateForm : function() {
            var row = new qx.ui.container.Composite(new qx.ui.layout.HBox(5, 'right'));
            var rpc = qr.data.Server.getInstance();
            var that = this;

            var deleteButton = new qx.ui.form.Button(this.tr("Delete"), 'icon/22/actions/dialog-close.png').set({ width : 50 });
            row.add(deleteButton, { flex : 1 });

            deleteButton.addListener('execute', function() {
                rpc.callAsyncSmart(function(ret) {
                    that.close();
                },
                'removeEntry', this._tableKey, this.getRecId());
            },
            this);

            var cancelButton = new qx.ui.form.Button(this.tr("Cancel"), 'icon/22/actions/dialog-cancel.png').set({ width : 50 });
            row.add(cancelButton, { flex : 1 });

            cancelButton.addListener('execute', function() {
                this.close();
            }, this);

            var sendButton = new qx.ui.form.Button(this.tr("Ok"), 'icon/22/actions/dialog-ok.png').set({ width : 50 });
            row.add(sendButton, { flex : 1 });

            sendButton.addListener('execute', function() {
                if (!this._form.validate()) {
                    return;
                }

                var data = this._form.getData();

                rpc.callAsyncSmart(function(ret) {
                    that.close();
                },
                'putEntry', this._tableKey, this.getRecId(), data);
            },
            this);

            this.addListener('changeRecId', function(e) {
                var recId = e.getData();
                deleteButton.setVisibility(recId ? 'visible' : 'hidden');
                if (recId) {
                    this.setEnabled(false);

                    rpc.callAsyncSmart(function(data) {
                        that._resv = data;
                        that._form.setData(data, true); /* only set fields that are available */
                        that.setEnabled(true);
                    },
                    'getEntry', this._tableKey, recId);
                }
            },
            this);

            this.add(row);
        }
    }
});
