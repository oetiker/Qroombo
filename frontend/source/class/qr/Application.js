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
            root.add(new qx.ui.basic.Atom(this.tr('Loading Qroombo ...')).set({
                center: true
            }),{
                left: 0,
                top: 0,
                bottom: 0,
                right: 0
            });

            var rpc = qr.data.Server.getInstance();
            rpc.callAsyncSmart(function(ret){
                qr.data.Config.getInstance().setConfig(ret);
                var desktop = qr.ui.Desktop.getInstance();
                root.add(desktop, {
                    left   : 10,
                    top    : 10,
                    bottom : 10,
                    right  : 10
                });
            },'getConfig');

        }
    }
});
