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
    properties: {
        userId: {
            event: 'userChanged',
            init: null
        },
        addrId: {
            event: 'addrChanged',
            init: null,
            apply: '_onAddrIdChange'
        },
        addrList: {
            event: 'addrListChanged',
            init: []
        }
    },
    members: {
        _cfg: null,
        _addrId: null,
        _userData: null,
        _addrList: null,            
        _onAddrIdChange: function(newValue,oldValue){
            this._userData.user_addr = newValue;
        },
        setConfig: function(data){
            this._cfg = data.cfg;
            var res = data.cfg.reservation;
            res.first_hour = parseInt(res.first_hour);
            res.last_hour = parseInt(res.last_hour);
            if (data.user){
                this.setUserData(data.user);
            }
            if (data.addrs){
                this.setAddrList(data.addrs);
            }
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
        },
        setUserData: function(data){
            this._userData = data;
            this.setUserId(data.user_id);
        },
        getUserName: function(){
            return this._userData.user_first + ' ' + this._userData.user_last;
        }
    }   
});
