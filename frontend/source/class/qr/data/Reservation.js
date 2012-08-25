/* ************************************************************************

   Copyrigtht: OETIKER+PARTNER AG
   License:    GPL V3 or later
   Authors:    Tobias Oetiker
   Utf8Check:  äöü

************************************************************************ */
/**
 * Represent a Reservation
 */

qx.Class.define('qr.data.Reservation', {
    extend : qx.core.Object,
    construct: function(set){
        this.base(arguments);
        this.set(set);
        this._cfg = qr.data.Config.getInstance();
    },
    properties : {
        /**
         * starting date of reservation
         */ 
        startDate: {},
        /**
         * starting Hour of the reservation
         */ 
        startHr : {},
        /**
         * duration of the reservation in hours
         */ 
        duration : {},
        /**
         * roomId
         */
        roomId: {},
        /**
         * if this reservation is stored on the server, a Reservation id 
         */
        resvId: {
            init: null,
            nullable: true
        },
        /**
         * the subject of the reservation
         */
        subject: {},        
        /**
         * can this reservation be edited?
         */
        editable: {}
    },
    members: {
        _cfg: null,
        getRow: function(){
            var rooms = this._cfg.getRoomList();
            var roomId = this.getRoomId();
            var row;
            rooms.forEach(function(room,i){
                if (room == roomId){
                    row = i+1;
                }
            });
            return row;
        },
        getColumn: function(){
            var cfg = this._cfg;
            var col = this.getStartHr() - cfg.getFirstHour();
            if (col < 0){
                col = 0;
            }
            return col + 1;
        },
        getColSpan: function(){
            var cfg = this._cfg;
            var end = this.getStartHr() + this.getDuration();
            if (end > cfg.getLastHour()){
                end = cfg.getLastHour();
            }
            if (end <= cfg.getFirstHour()){
                return 0;
            }
            return end - this.getStartHr();
        }
    }
});
