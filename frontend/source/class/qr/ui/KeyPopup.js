/* ************************************************************************
   Copyright: 2012 OETIKER+PARTNER AG
   License:   GPLv3 or later
   Authors:   Tobi Oetiker <tobi@oetiker.ch>
   Utf8Check: äöü
************************************************************************ */
/*
*/
/**
  * get details on booking
  */
qx.Class.define("qr.ui.KeyPopup", {
    extend : qx.ui.window.Window,
    construct : function(cfg){                
        this.base(arguments,this.tr('Access Verification'));
        this.set({
            allowClose: true,
            allowMaximize: false,
            allowMinimize: false,
            showClose: true,
            showMaximize: false,
            showMinimize: false,
            showStatusbar: false,
            width: 400,
            layout: new qx.ui.layout.VBox(10),
            modal: true
        });
        
        this._addForm(cfg);
    },
    events: {
        loginSucceeded: 'qx.event.type.Data'
    },
    members : {
        _mkHeader: function(lbl){
            return new qx.ui.basic.Label(lbl).set({
                rich: true,
                font: 'bold',
                paddingTop: 5
            }); 
        },
        _addForm: function(cfg){
            this.add(new qx.ui.basic.Label(this.tr('You Access Key has just been sent to the eMail address you provided in the previous dialog. Please enter the Access Key in the field below.')).set({
                rich: true
            }));
            var keyForm =  new qr.ui.AutoForm([
                {
                    key: 'key',
                    label: this.tr('Access Key'),
                    widget: 'text',
                    set: {
                        required: true
                    }
                }                 
            ],new qx.ui.layout.VBox(5));            
            var  keyCtrl = keyForm.getControl('key');
            this.addListener('appear',function(){
                this.center();
                keyCtrl.focus();
            },this);
            this.add(keyForm);

            if (! cfg.userId){
                this.add(this._mkHeader(this.tr('Please provide some additional details about yourself.')));
                var userForm = new qr.ui.AutoForm(cfg.userForm,new qx.ui.layout.VBox(5));
                userForm.setData({user_email: cfg.eMail});
                this.add(userForm);            
                this.add(this._mkHeader(this.tr('What address should be on your invoice?')));
                var addrForm = new qr.ui.AutoForm(cfg.addrForm,new qx.ui.layout.VBox(5));
                this.add(addrForm);
            }
            var row = new qx.ui.container.Composite(new qx.ui.layout.HBox(5,'right'))

            var loginButton = new qx.ui.form.Button(this.tr("Login"));
            var rpc = qr.data.Server.getInstance();
            var that = this;
            row.add(loginButton);
            this.add(row);
            loginButton.addListener('execute',function(){
                if (!keyForm.validate()){
                    return;
                }
                var keyData = keyForm.getData();
                if (userForm){                    
                    if (!userForm.validate() || !addrForm.validate()){
                        return;
                    }
                    var userData = userForm.getData();
                    var addrData = addrForm.getData();
                }
                rpc.callAsyncSmart(function(ret){
                    that.close();
                    var cfg = qr.data.Config.getInstance();
                    cfg.setAddrList(ret.addrs);
                    cfg.setUserData(ret.user);
                    qr.ui.Booker.getInstance().reload();
                    that.getApplicationRoot().remove(that);
                    that.dispose();
                },'login',cfg.eMail,keyData.key,userData,addrData);
            },this);
        }
    }    
});
