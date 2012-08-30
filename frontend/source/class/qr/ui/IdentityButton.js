/* ************************************************************************
   Copyright: 2012 OETIKER+PARTNER AG
   License:   GPLv3 or later
   Authors:   Tobi Oetiker <tobi@oetiker.ch>
   Utf8Check: äöü
************************************************************************ */
/*
#asset(qx/icon/${qx.icontheme}/22/actions/system-shutdown.png)
*/

/**
  * let the user login, logoff and switch address
  */
qx.Class.define("qr.ui.IdentityButton", {
    extend : qx.ui.core.Widget,
    type: 'singleton',
    construct : function() {                
        this.base(arguments);
        var grid = new qx.ui.layout.HBox(10);
        this._setLayout(grid);
        this._ctrl = {};
        this._createControl('addrLbl');
        this._createControl('addrSel');
        this._createControl('loginBtn');
        this._createControl('logoffBtn');

        var cfg = qr.data.Config.getInstance();

        cfg.addListener('changeUserId', this._updateLoginButton, this);
        cfg.addListener('changeAddrList',this._updateAddrSelector,this);
        cfg.addListener('changeAddrId',this._syncAddrSelector,this);
        
    },
    members : {
        _syncingAddr: null,
        _addrController: null,
        _ctrl: null,
        _createControl: function(id) {
            var control;
            var cfg = qr.data.Config.getInstance();
            var userId = cfg.getUserId();
            var addrList = cfg.getAddrList();
            var addrId = cfg.getAddrId();
            switch(id) {
                case "loginBtn":
                    control = new qx.ui.form.Button(this.tr('Login')).set({
                        visibility: userId ? 'excluded' : 'visible'
                    });
                    this._add(control);
                    control.addListener('execute',this._onExecLogin,this);
                    break;
                case "logoffBtn":
                    control = new qx.ui.form.Button(null,'icon/22/actions/system-shutdown.png').set({
                        visibility: userId ? 'visible': 'excluded'
                    });
                    this._add(control);
                    control.addListener('execute',this._onExecLogoff,this);
                    break;
                case "addrLbl":
                    control = new qx.ui.basic.Label().set({
                        visibility: addrList.length == 1 ? 'visible' : 'excluded',
                        alignY: 'middle'
                    });
                    this._add(control)
                    break;
                case "addrSel":
                    var currentItem = 0;
                    var model = qx.data.marshal.Json.createModel(
                        addrList.length 
                        ? addrList.map(function(row,i){
                            if (row.addr_id == addrId){
                                currentItem = i
                            }
                            return {
                               key: row.addr_id,
                               label: ( row.addr_org ? row.addr_org + ', ' : '' ) + row.addr_contact
                            }
                         })
                        : [{ label: 'Waiting for data', key: null}]
                    );
                    control = new qx.ui.form.VirtualSelectBox(model).set({
                        labelPath: 'label', 
                        visibility: addrList.length > 1 ? 'visible': 'excluded',
                        width: 300,
                        maxListHeight: null
                    });

                    var dropdown = control.getChildControl('dropdown');
                    dropdown.addListener('resize',function(e){
                        dropdown.setWidth(400);
                    });

                    if (addrList.length){
                        control.getSelection().push(model.getItem(currentItem));
                        this._ctrl.addrLbl.setValue(model.getItem(currentItem).getLabel());
                    }
                    control.addListener('changeSelection',this._onChangeAddrSelection,this);
                    this._add(control);
                    break;
            }
            this._ctrl[id] = control;
            return control;
        },
        _onExecLogoff: function(){
            var cfg = qr.data.Config.getInstance();
            var rpc = qr.data.Server.getInstance();
            if (cfg.getUserId()){
                rpc.callAsyncSmart(function(ret){
                    cfg.clearUserData();
                    qr.ui.Booker.getInstance().reload();
                },'logout');
            }
        },
        _onExecLogin: function(){
            qr.ui.LoginPopup.getInstance().show();
        },
        _onChangeAddrSelection: function(e){
            var addrId = e.getData().getItem(0).getKey();
            if (addrId){
                var cfg = qr.data.Config.getInstance();
                var rpc = qr.data.Server.getInstance();
                var addrSel = this._ctrl.addrSel;
                addrSel.enabled(false);
                var that = this;
                rpc.callAsyncSmart(function(ret){
                    that._syncingAddr = true;
                    cfg.setAddrId(ret);
                    that._syncingAddr = false;
                },'setAddrId',addrId);
            }
        },
        _syncAddrSelector: function(e){
            var addrId = e.getData();
            if (!addrId) return;
            var cfg = qr.data.Config.getInstance();
            var addrSel = this._ctrl.addrSel;
            this._syncingAddr = true;
            var model = addrSel.getModel();
            var currentItem = 0;
            model.forEach(function(item,i){
                if (item.getKey() == addrId){
                    currentItem = i;
                }
            });
            addrSel.getSelection().push(model.getItem(currentItem));
            this._ctrl.addrLbl.setValue(model.getItem(currentItem).getLabel());
            this._syncingAddr = false;
        },
        _updateAddrSelector: function(e){
            var list = e.getData();
            var addrSel = this._ctrl.addrSel;
            if (!list || list.length == 0){
                addrSel.exclude();
                this._ctrl.addrLbl.exclude();                
                return;
            }
            if (list.length == 1){
                this._ctrl.addrLbl.show();
                addrSel.exclude();
            }
            else {
                this._ctrl.addrLbl.exclude();
                addrSel.show();                
            }
            var model = qx.data.marshal.Json.createModel(
                list.map(function(row){
                    return {
                       key: row.addr_id,
                       label: ( row.addr_org ? row.addr_org + ', ' : '' ) + row.addr_contact
                    }
                })
            );
            addrSel.setModel(model);
        },
        _updateLoginButton: function(e){
            var userId = e.getData();
            this._ctrl.loginBtn.setVisibility(userId ? 'excluded' : 'visible');
            this._ctrl.logoffBtn.setVisibility(userId ? 'visible' : 'excluded');
        }        
    }        
});

