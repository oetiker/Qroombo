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
        this.base(arguments);

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

        cfg.addListener('changeAddrId', this._updateForm, this);
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
        _recId : null,
        _tableKey : null,

        /**
         * TODOC
         *
         * @param reservation {var} TODOC
         */
        show : function(recId) {
            var addrId = this._cfg.getAddrId();

            if (!addrId) {
                return;
            }

            if (this._form) {
                this.setRecId(recId);
                this.base(arguments);
            }
            else {
                this.addListenerOnce('changeForm', function() {
                    this.setRecId(recId);
                    this.base(arguments);
                },
                this);
            }
            this._recId = recId;
        },


        /**
         * TODOC
         *
         * @param e {Event} TODOC
         */
        _updateForm : function(e) {

            /* skip if the addr id did not really change */

            var addrId = e && e.getData() || qr.data.Config.getInstance().getAddrId();

            if (this._lastAddrId == addrId) {
                return;
            }

            this._lastAddrId = addrId;
            var that = this;
            this.setEnabled(false);

            var currencyFormat = new qx.util.format.NumberFormat().set({
                maximumFractionDigits : 2,
                minimumFractionDigits : 2,
                prefix                : qr.data.Config.getInstance().getCurrency() + ' '
            });

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
                'removeEntry', this._tableKey, this._recId);
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
                'putEntry', this._tableKey, this._recId, data);
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
