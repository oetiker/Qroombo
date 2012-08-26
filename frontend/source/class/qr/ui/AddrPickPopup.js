/* ************************************************************************
   Copyright: 2012 OETIKER+PARTNER AG
   License:   GPLv3 or later
   Authors:   Tobi Oetiker <tobi@oetiker.ch>
   Utf8Check: äöü
************************************************************************ */
/*
#asset(qx/icon/${qx.icontheme}/16/actions/go-next.png)
*/
/**
  * get details on booking
  */
qx.Class.define("qr.ui.AddrPickPopup", {
    extend : qx.ui.window.Window,
    type: 'singleton',
    construct : function() {                
        this.base(arguments,this.tr('Adress Selection'));
        this.set({
            allowClose: true,
            allowMaximize: false,
            allowMinimize: false,
            showClose: true,
            showMaximize: false,
            showMinimize: false,
            showStatusbar: false,
            width: 400,
            layout: new qx.ui.layout.VBox(15),
            modal: true
        });
        
        this.add(new qx.ui.basic.Label(this.tr('Please select the Address for your bookings.')).set({
                rich: true,
                paddingTop: 10
        }));            
        this._cfg = qr.data.Config.getInstance();
        this._addForm();
    },
    events: {
        keyRequested: 'qx.event.type.Data'
    },
    members : {
        _form: null,
        _cfg: null,
        _addForm: function(){
            var form = this._form = new qr.ui.AutoForm([
                {
                    key: 'addrId',      
                    label: this.tr('Invoice Address'),
                    widget: 'selectBox',
                    set: {
                        required: true
                    }
                }
            ],new qx.ui.layout.VBox(5));
            this.add(form);
            var row = new qx.ui.container.Composite(new qx.ui.layout.HBox(5,'right'));
            var okButton = new qx.ui.form.Button(this.tr("Ok"));
            row.add(okButton);
            this.add(row);

            var listCtrl = form.getControl('addrId')
            listCtrl.addListener('keyup',function(e){
                if (e.getKeyIdentifier() == 'Enter'){
                    okButton.execute();
                }
            });

            this.addListener('appear',function(){
                this.center();
                listCtrl.focus();
            },this);

            var rpc = qr.data.Server.getInstance();
            var that = this;
            okButton.addListener('execute',function(e){
                if (! form.validate()){
                    return;
                }
                var data = form.getData();
                rpc.callAsyncSmart(function(ret){
                    that.close();
                    that._cfg.setAddrId(ret);
                },'setAddrId',data.addrId);
            },this);
                
            this._cfg.addListener('addrListChanged',function(e){        
                var list = e.getData();
                if (list.length == 1){
                    rpc.callAsyncSmart(function(ret){
                        that._cfg.setAddrId(ret);
                    },'setAddrId',list[0].addr_id);
                    return;
                }
                this._form.setSelectBoxData(
                    list.map(function(row){
                        return {
                            key: row.addr_id,
                            title: ( row.addr_org ? row.addr_org + ' ' : '' ) + row.addr_contact
                        }
                    })
                );
                this._form.setData({
                    addrId: this._cfg.getUser().user_addr
                });
                this.open();
            },this);
        }
    }    
});
