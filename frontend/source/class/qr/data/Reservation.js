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
    construct: function(resv){
        this.base(arguments);
        this._cfg = qr.data.Config.getInstance();
        if (resv){
            this.setResvRecord(resv);
        }
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
        },
        setResvRecord: function(rec){
            var date = new Date(parseInt(rec.resv_start)*1000);
            this.set({
                startDate: new Date(date.getUTCFullYear(),date.getUTCMonth(),date.getUTCDate(),0,0,0),
                startHr:   date.getUTCHours(),
                duration:  parseInt(rec.resv_len),
                subject:   rec.resv_subj || '-',
                roomId:    rec.resv_room,
                resvId:    rec.resv_id,
                editable:  rec.resv_addr == this._cfg.getAddrId()
            });
            return this;
        },
        dateMatch: function(date){
            var start = this.getStartDate();
            return date.getFullYear() == start.getFullYear() && date.getMonth() == start.getMonth() && date.getDate() == start.getDate();            
        }
    }
});
