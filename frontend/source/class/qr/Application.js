/* ************************************************************************
   Copyright: 2012 OETIKER+PARTNER AG
   License:   GPLv3 or later
   Authors:   Tobi Oetiker <tobi@oetiker.ch>
   Utf8Check: äöü
************************************************************************ */

/* ************************************************************************
#asset(qr/*)
************************************************************************ */

/**
 * This is the main application class of your custom application "qr"
 */
qx.Class.define("qr.Application", {
    extend : qx.application.Standalone,

    members : {
        /**
         * This method contains the initial application code and gets called 
         * during startup of the application
         *
         * @lint ignoreDeprecated(alert)
         */
        main : function() {
            this.base(arguments);

            if (qx.core.Environment.get("qx.debug")) {
                qx.log.appender.Native;
                qx.log.appender.Console;
            }

            var root = this.getRoot();

            root.add(new qx.ui.basic.Atom(this.tr('Loading Qroombo ...', 'qr/loader.gif')).set({
                center       : true,
                iconPosition : 'top'
            }),
            {
                left   : 0,
                top    : 0,
                bottom : 0,
                right  : 0
            });

            var tokenfield = this._mkTokenfield();

            [ 'yes', 'you', 'sir' ].forEach(function(str) {
                tokenfield.addToken({ label : str }, true);
            });

            var rpc = qr.data.Server.getInstance();

            rpc.callAsyncSmart(function(ret) {
                /**
                 order is important as addrpick will observer the addrlist
                 in config to ask for addr choice if multiple addresses are
                 on offer 
                 **/
                qr.data.Config.getInstance().setConfig(ret);
                var desktop = qr.ui.Desktop.getInstance();

                root.add(desktop, {
                    left   : 10,
                    top    : 10,
                    bottom : 10,
                    right  : 10
                });

                root.add(qr.ui.IdentityButton.getInstance(), {
                    top   : 10,
                    right : 10
                });

                root.add(tokenfield, {
                    top  : 10,
                    left : 10
                });
            },
            'getConfig');
        },


        /**
         * TODOC
         *
         * @return {var} TODOC
         */
        _mkTokenfield : function() {
            var t = new qr.ui.Token().set({
                width         : 500,
                maxWidth      : 500,
                selectionMode : 'multi'
            });

            /*
             * listens for event to load data from the server. here, we
             * do a simple mockup with a small timeout to simulate a server request
             */

            t.addListener("loadData", function(e) {
                var str = e.getData();
                var data = [];

                for (var i=0; i<(Math.floor(Math.random()*10)+3); i++) {
                    data.push({ label : str + " " + i });
                }

                t.populateList(str, data);
            },
            this);

            return t;
        }
    }
});