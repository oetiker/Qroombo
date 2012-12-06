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

    properties : {
        userId : {
            event    : 'changeUserId',
            init     : null,
            nullable : true
        },

        addrId : {
            event    : 'changeAddrId',
            init     : null,
            nullable : true,
            apply    : '_onAddrIdChange'
        },

        addrList : {
            event : 'changeAddrList',
            init  : []
        }
    },

    members : {
        _cfg : null,
        _addrId : null,
        _userData : null,
        _addrList : null,
        _tabView: null,

        /**
         * TODOC
         *
         * @param newValue {var} TODOC
         * @param oldValue {var} TODOC
         */
        _onAddrIdChange : function(newValue, oldValue) {
            this._userData.user_addr = newValue;
        },


        /**
         * TODOC
         *
         * @param data {var} TODOC
         */
        setConfig : function(data) {
            this._cfg = data.cfg;
            this._tabView = data.tabView;
            var res = data.cfg.reservation;
            res.first_hour = parseInt(res.first_hour);
            res.last_hour = parseInt(res.last_hour);

            if (data.user && data.user.user_id) {
                this.setUserData(data.user);
            }

            if (data.addrs && data.addrs.length > 0) {
                this.setAddrList(data.addrs);
                this.setAddrId(data.user.user_addr);
            }
        },


        /**
         * TODOC
         *
         * @return {var} TODOC
         */
        getCurrency : function() {
            return this._cfg.general.currency;
        },


        /**
         * TODOC
         *
         * @return {var} TODOC
         */
        getRoomList : function() {
            return this._cfg.room.list;
        },


        /**
         * TODOC
         *
         * @param id {var} TODOC
         * @return {var} TODOC
         */
        getRoomInfo : function(id) {
            return this._cfg.room.info[id];
        },


        /**
         * TODOC
         *
         * @return {var} TODOC
         */
        getFirstHour : function() {
            return this._cfg.reservation.first_hour;
        },


        /**
         * TODOC
         *
         * @return {var} TODOC
         */
        getLastHour : function() {
            return this._cfg.reservation.last_hour;
        },


        /**
         * TODOC
         *
         */
        clearUserData : function() {
            this.setAddrId(null);
            this.setAddrList([]);
            this._userData = null;
            this.setUserId(null);
        },


        /**
         * TODOC
         *
         * @param data {var} TODOC
         */
        setUserData : function(data) {
            this._userData = data;
            this.setUserId(data.user_id);
            this.setAddrId(data.user_addr);
        },


        /**
         * TODOC
         *
         * @return {null | var} TODOC
         */
        getUserName : function() {
            var uD = this._userData;

            if (!uD) {
                return null;
            }

            return uD.user_first + ' ' + uD.user_last;
        },


        /**
         * TODOC
         *
         * @return {null | var} TODOC
         */
        getUserAddr : function() {
            var aI = this.getAddrId();

            if (!aI) {
                return null;
            }

            var aL = this.getAddrList();
            var ret = this.getUserName();

            if (aL.length == 1) {
                return ret;
            }

            aL.forEach(function(ad) {
                if (ad.addr_id == aI) {
                    if (ad.addr_org) {
                        ret += ' / ' + ad.addr_org;
                    } else {
                        ret += ' / ' + ad.addr_str;
                    }

                    ret += ', ' + ad.addr_town;
                }
            });

            return ret;
        },

        getTabView: function(tab){
            return this._tabView[tab];
        }
    }
});
