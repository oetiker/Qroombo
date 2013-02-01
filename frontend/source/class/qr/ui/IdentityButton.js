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
  * let the user login, logoff
  */
qx.Class.define("qr.ui.IdentityButton", {
    extend : qx.ui.core.Widget,
    type : 'singleton',

    construct : function() {
        this.base(arguments);
        var grid = new qx.ui.layout.HBox(10);
        this._setLayout(grid);
        this._ctrl = {};
        this._createControl('loginBtn');
        this._createControl('logoffBtn');

        var cfg = qr.data.Config.getInstance();

        cfg.addListener('changeUserId', this._updateLoginButton, this);
    },

    members : {
        _ctrl : null,


        /**
         * TODOC
         *
         * @param id {var} TODOC
         * @return {var} TODOC
         */
        _createControl : function(id) {
            var control;
            var cfg = qr.data.Config.getInstance();
            var userId = cfg.getUserId();

            switch(id)
            {
                case "loginBtn":
                    control = new qx.ui.form.Button(this.tr('Login')).set({ visibility : userId ? 'excluded' : 'visible' });
                    this._add(control);
                    control.addListener('execute', this._onExecLogin, this);
                    break;

                case "logoffBtn":
                    control = new qx.ui.form.Button(null, 'icon/22/actions/system-shutdown.png').set({ visibility : userId ? 'visible' : 'excluded' });
                    this._add(control);
                    control.addListener('execute', this._onExecLogoff, this);
                    break;
            }

            this._ctrl[id] = control;
            return control;
        },


        /**
         * TODOC
         *
         */
        _onExecLogoff : function() {
            var cfg = qr.data.Config.getInstance();
            var rpc = qr.data.Server.getInstance();

            if (cfg.getUserId()) {
                rpc.callAsyncSmart(function(ret) {
                    cfg.clearUserData();
                    qr.ui.Booker.getInstance().reload();
                },
                'logout');
            }
        },


        /**
         * TODOC
         *
         */
        _onExecLogin : function() {
            qr.ui.LoginPopup.getInstance().show();
        },

        /**
         * TODOC
         *
         * @param e {Event} TODOC
         */
        _updateLoginButton : function(e) {
            var userId = e.getData();
            this._ctrl.loginBtn.setVisibility(userId ? 'excluded' : 'visible');
            this._ctrl.logoffBtn.setVisibility(userId ? 'visible' : 'excluded');
        }
    }
});