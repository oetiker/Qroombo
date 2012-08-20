/* ************************************************************************

   Copyrigtht: OETIKER+PARTNER AG
   License:    GPL V3 or later
   Authors:    Tobias Oetiker
   Utf8Check:  äöü

************************************************************************ */
/**
 * This object holds the global configuration for the web frontend.
 * it gets read at application startup
 */

qx.Class.define('qr.data.Config', {
    extend : qx.core.Object,
    type : 'singleton',

    events: {
        ready: 'qx.event.type.Event'
    },
    properties : {
        /**
         * the FRONTEND config from the master config file.
         */
        reservation: {},
        room: {},
        user: {},
        general: {},
        address: {}
    }
});
