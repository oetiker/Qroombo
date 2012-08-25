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
qx.Class.define("qr.ui.Reservation", {
    extend : qx.ui.window.Window,
    type: 'singleton',
    construct : function() {                
        this.base(arguments,this.tr('Reservation Detail'));
        this.set({
            allowClose: true,
            allowMaximize: false,
            allowMinimize: false,
            showClose: true,
            showMaximize: false,
            showMinimize: false,
            showStatusbar: false,
            width: 400,
            layout: new qx.ui.layout.VBox(),
            modal: true
        });
        var cfg = this._cfg = qr.data.Config.getInstance();
        cfg.addListener('addrChanged',this._updateForm,this);
        this.addListener('appear',function(){this.center()},this);
        this._addButtons();
    },
    properties: {
    },
    events: {
    },
    members : {
        _cfg: null,
        _form: null,
        show: function(reservation){
            var addrId = this._cfg.getAddrId();
            if (!addrId){
                this._cfg.addListenerOnce('addrChanged',function(){
                    this.show();
                },this);
                var login = new qr.ui.LoginPopup();
                login.show();
                return;
            }
            // ok now we open for real as we are now authenticated
            this.base(arguments);
        },
        _updateForm: function(){
            var rpc = qr.data.Server.getInstance();
            var that = this;
            that.setEnabled(false);
            rpc.callAsyncSmart(function(form){
                if (that._form){
                    that.remove(that._form);
                    that._form.dispose();
                }
                that._form = new qr.ui.AutoForm(form,new qx.ui.layout.VBox(5));
                that.addAt(that._form,0);
                that.setEnabled(true);
            },'getForm','resv');
        },
        _addButtons: function(){
            var row = new qx.ui.container.Composite(new qx.ui.layout.HBox(5,'right'))
            var deleteButton = new qx.ui.form.Button(this.tr("Delete"),'icon/22/actions/dialog-close.png').set({
                width: 50
            });
            row.add(deleteButton,{flex: 1});
            var cancelButton = new qx.ui.form.Button(this.tr("Cancel"),'icon/22/actions/dialog-cancel.png').set({
                width: 50
            });
            row.add(cancelButton,{flex: 1});
            var sendButton = new qx.ui.form.Button(this.tr("Ok"),'icon/22/actions/dialog-ok.png').set({
                width: 50
            });
            row.add(sendButton,{flex: 1});
            this.add(row);
        }
    }    
});
