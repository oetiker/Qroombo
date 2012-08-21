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
    members: {
        _cfg: null,
        setConfig: function(cfg){
            this._cfg = cfg;
            var res = cfg.reservation;
            res.first_hour = parseInt(res.first_hour);
            res.last_hour = parseInt(res.last_hour);            
        },
        getRoomList: function(){
            return this._cfg.room.list;
        },
        getRoomInfo: function(id){
            return this._cfg.room.info[id];
        },
        getFirstHour: function(){
            return this._cfg.reservation.first_hour;
        },
        getLastHour: function(){
            return this._cfg.reservation.last_hour;
        }
    }   
});
