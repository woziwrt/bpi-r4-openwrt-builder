'use strict';
'require rpc';
'require form';
'require network';

var callFileList = rpc.declare({
	object: 'file',
	method: 'list',
	params: [ 'path' ],
	expect: { entries: [] },
	filter: function(list, params) {
		var rv = [];
		for (var i = 0; i < list.length; i++)
			if (list[i].name.match(/^ttyUSB/) || list[i].name.match(/^ttyACM/))
				rv.push(params.path + list[i].name);
		return rv.sort();
	}
});

network.registerPatternVirtual(/^atc-.+$/);
network.registerErrorCode('REG_FAILED',  _('Registration failed'));
network.registerErrorCode('PLMN_FAILED', _('Setting PLMN failed'));
network.registerErrorCode('NO_IFACE',    _('No intertface found'));
network.registerErrorCode('MODEM',       _('Wrong atc script'));


return network.registerProtocol('atc', {
	getI18n: function() {
		return _('AT commands');
	},

	getIfname: function() {
		return this._ubus('l3_device') || 'atc-%s'.format(this.sid);
	},

	getOpkgPackage: function() {
		return 'atc';
	},

	isFloating: function() {
		return true;
	},

	isVirtual: function() {
		return true;
	},

	getDevices: function() {
		return null;
	},

	containsDevice: function(ifname) {
		return (network.getIfnameOf(ifname) == this.getIfname());
	},

	renderFormOptions: function(s) {
		var dev = this.getL3Device() || this.getDevice(), o;

		o = s.taboption('general', form.Value, '_modem_device', _('Modem device'));
		o.ucioption = 'device';
		o.rmempty = false;
		o.load = function(section_id) {
			return callFileList('/dev/').then(L.bind(function(devices) {
				for (var i = 0; i < devices.length; i++)
					this.value(devices[i]);
				return form.Value.prototype.load.apply(this, [section_id]);
			}, this));
		};

		o = s.taboption('general', form.Value, 'apn', _('APN'));
		o.validate = function(section_id, value) {
			if (value == null || value == '')
				return true;

			if (!/^[a-zA-Z0-9\-.]*[a-zA-Z0-9]$/.test(value))
				return _('Invalid APN provided');
			return true;
		};

		o = s.taboption('general', form.Value, 'pincode', _('PIN'));
		o.datatype = 'and(uinteger,minlength(4),maxlength(8))';

		o = s.taboption('general', form.ListValue, 'auth', _('Authentication Type'));
		o.value('0', _('NONE'));
		o.value('1', _('PAP'));
		o.value('2', _('CHAP'));
		o.default = '0';

		o = s.taboption('general', form.Value, 'username', _('PAP/CHAP username'));
		o.depends('auth', '1');
		o.depends('auth', '2');

		o = s.taboption('general', form.Value, 'password', _('PAP/CHAP password'));
		o.depends('auth', '1');
		o.depends('auth', '2');
		o.password = true;

		o = s.taboption('general', form.ListValue, 'pdp', _('PDP Type'));
		o.value('IP', _('IPv4'));
		o.value('IPV4V6', _('IPv4/IPv6'));
		o.value('IPV6', _('IPv6'));
		o.default = 'IP';

		o = s.taboption('general', form.ListValue, 'atc_debug', _('Activate AT debugging'),
			_('AT commands and unsolicited result codes are displayed in syslog. Default will not dispaly cell and signal info.'));
		o.value('0', _('None'));
		o.value('1', _('Default'));
		o.value('2', _('All'));
		o.default = 0;

		o = s.taboption('advanced', form.Value, 'delay', _('Modem boot timeout'),
			_('Amount of seconds to wait during boot for the modem to become ready'));
		o.placeholder = '15';
		o.datatype    = 'min(1)';

		o = s.taboption('advanced', form.Flag, 'v6dns_ra', _('IPv6 DNS servers via Router Advertisment.'));
		o.default = o.disabled;

		o = s.taboption('advanced', form.DynamicList, 'custom_at', _('Add custom AT-commands'),
			_('Custom AT-commands will be run before modem is activated.'));
		s.datatype = 'string';

		o = s.taboption('advanced', form.Value, 'mtu', _('Override MTU'));
		o.placeholder = dev ? (dev.getMTU() || '1500') : '1500';
		o.datatype    = 'max(9200)';

		o = s.taboption('advanced', form.Flag, 'defaultroute',
			_('Use default gateway'),
			_('If unchecked, no default route is configured'));
		o.default = o.enabled;

		o = s.taboption('advanced', form.Value, 'metric',
			_('Use gateway metric'));
			o.placeholder = '0';
		o.datatype = 'uinteger';
		o.depends('defaultroute', '1');

		o = s.taboption('advanced', form.Flag, 'peerdns',
			_('Use DNS servers advertised by peer'),
			_('If unchecked, the advertised DNS server addresses are ignored'));
		o.default = o.enabled;

		o = s.taboption('advanced', form.DynamicList, 'dns', _('Use custom DNS servers'));
		o.depends('peerdns', '0');
		o.datatype = 'ipaddr';
	}
});
