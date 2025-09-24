'use strict';
'require form';
'require fs';
'require view';
'require ui';
'require uci';
'require dom';
'require tools.widgets as widgets';

/*

  Copyright 2025 Rafał Wabik - IceG - From eko.one.pl forum
  
  MIT License
  
*/

function handleOpen(ev) {
	if (ev === 'ropenissues')      { window.open('https://github.com/4IceG/luci-app-modemdata/issues'); return; }
	if (ev === 'copenissues')      { window.open('https://github.com/obsy/modemdata/issues'); return; }
	if (ev === 'opendiscussion')   { window.open('https://github.com/4IceG/luci-app-modemdata/discussions'); return; }
	if (ev === 'ropencoffee')      { window.open('https://suppi.pl/rafalwabik'); return; }
	if (ev === 'copencoffee')      { window.open('https://buycoffee.to/eko.one.pl'); return; }
	if (ev === 'opensupport')      { window.open('https://github.com/sponsors/4IceG'); return; }
	if (ev === 'opentopic')        { window.open('https://eko.one.pl/forum/viewtopic.php?id=24829'); return; }
}

let ModemDataInfo = form.DummyValue.extend({
	load: function() {
		let author = _('%sCezary Jackiewicz (obsy)%s.')
			.format('<a href="https://github.com/obsy" target="_blank">', '</a>');

		let luci_author = _('%sRafał Wabik (IceG)%s.')
			.format('<a href="https://github.com/4IceG" target="_blank">', '</a>');

		let btnRow = { 'class': 'btn-row', 'style': 'display:flex; flex-wrap:wrap; gap:8px; align-items:center;' };

		return E([
			E('div', { 'class': 'cbi-section' }, [
				E('style', {}, `

					.cbi-section .btn-row .cbi-button { margin: 0; }
				`),

				E('h3', _('Modemdata Info')),

				E('div', { 'class': 'cbi-value' }, [
					E('label', { 'class': 'cbi-value-title', 'style': 'padding-top:0rem' },
						_('Author (package maintainer)')),
					E('div', { 'class': 'cbi-value-field', 'id': 'author-obsy', 'style': 'color:#37c' }, author)
				]),

				E('div', { 'class': 'cbi-value' }, [
					E('label', { 'class': 'cbi-value-title', 'style': 'padding-top:0rem' }, _('Available options')),
					E('div', { 'class': 'cbi-value-field', 'id': 'actions-obsy' }, [
						E('div', btnRow, [
							E('button', {
								'class': 'cbi-button cbi-button-action important',
								'id': 'btn-coffee-obsy',
								'data-tooltip': _('Buy a coffee if you want to support the development of the project and the author'),
								'click': ui.createHandlerFn(this, function () { return handleOpen('copencoffee'); })
							}, [_('Buy a coffee')]),
							E('button', {
								'class': 'cbi-button cbi-button-remove',
								'id': 'btn-bug-obsy',
								'data-tooltip': _('Report a bug on the package Github page'),
								'click': ui.createHandlerFn(this, function () { return handleOpen('copenissues'); })
							}, [_('Report a bug')])
						])
					])
				]),

				E('hr'),
				E('h3', _('Luci-app-modemdata Info')),

				E('div', { 'class': 'cbi-value' }, [
					E('label', { 'class': 'cbi-value-title', 'style': 'padding-top:0rem' },
						_('Author (package maintainer)')),
					E('div', { 'class': 'cbi-value-field', 'id': 'author-iceg', 'style': 'color:#37c' },
						luci_author)
				]),

				E('div', { 'class': 'cbi-value' }, [
					E('label', { 'class': 'cbi-value-title', 'style': 'padding-top:0rem' }, _('Available options')),
					E('div', { 'class': 'cbi-value-field', 'id': 'actions-iceg' }, [
						E('div', btnRow, [
							E('button', {
								'class': 'cbi-button cbi-button-action important',
								'id': 'btn-coffee-iceg',
								'data-tooltip': _('Buy a coffee if you want to support the development of the project and the author'),
								'click': ui.createHandlerFn(this, function () { return handleOpen('ropencoffee'); })
							}, [_('Buy a coffee')]),
							E('button', {
								'class': 'cbi-button cbi-button-action',
								'id': 'btn-sponsor-iceg',
								'data-tooltip': _('Become a sponsor if you want to support the development of the project and the author'),
								'click': ui.createHandlerFn(this, function () { return handleOpen('opensupport'); })
							}, [_('Become a sponsor')]),
							E('button', {
								'class': 'cbi-button cbi-button-add',
								'id': 'btn-forum-iceg',
								'data-tooltip': _('Write in the topic of the package on the forum eko.one.pl'),
								'click': ui.createHandlerFn(this, function () { return handleOpen('opentopic'); })
							}, [_('Write on forum')]),
							E('button', {
								'class': 'cbi-button cbi-button-neutral',
								'id': 'btn-discuss-iceg',
								'data-tooltip': _('Open a package discussion on Github'),
								'click': ui.createHandlerFn(this, function () { return handleOpen('opendiscussion'); })
							}, [_('Open discussion')]),
							E('button', {
								'class': 'cbi-button cbi-button-remove',
								'id': 'btn-bug-iceg',
								'data-tooltip': _('Report a bug on the package Github page'),
								'click': ui.createHandlerFn(this, function () { return handleOpen('ropenissues'); })
							}, [_('Report a bug')])
						])
					])
				]),
				E('hr'),
			])
		]);
	}
});

let Troubleshooting = form.DummyValue.extend({
	load: function() {
		let help1 = '<em>'+_('Go to the Diagnostics tab and run a script check. Most often, the error is caused by a strange operator name. To fix this, select the Force PLMN from file option if it is available in the modem configuration options.')+'</em>';
		return E([
			E('div', { 'class': 'cbi-section' }, [
				E('h5', _('If data in LuCI is not visible, and we are 100% sure that the modem has been defined/configured correctly.')),
				E('div', { 'class': 'cbi-value' }, [
					E('label', { 'class': 'cbi-value-title', 'style': 'padding-top:0rem' }, _('Suggested solution')+': '),
					E('div', { 'class': 'cbi-value-field', 'id': 'installedcompiled', 'style': '' }, help1)
				]),
			])
		]);
	}
});

return view.extend({
	load: function () {
		uci.load('modemdata');
	},

	render: function (data) {
		let m, s, o;

		let info = _('In the future tab will allow you to update the package from %sRafał (IceG) external repository%s.')
			.format('<a href="https://github.com/4IceG/Modem-extras-apk" target="_blank">', '</a>');

		m = new form.Map('modemdata', _('Package update and support'), info);

		s = m.section(form.NamedSection, 'global');
		s.render = L.bind(function (view, section_id) {
			return E('div', { 'class': 'cbi-section' }, [
				E('div', {
					'class': 'ifacebox',
					'style': 'display:flex; flex-wrap:wrap; align-items:center; gap:8px; max-width:100%;'
				}, [
					E('strong', { 'style': 'flex:0 0 auto;' }, _('Info')),
					E('span', {
						'style': 'flex:1 1 0; min-width:0; white-space:normal; overflow-wrap:anywhere;'
					}, _('Option will appear after apk implementation.')),
				]),
				E('br'),
			]);
		}, o, this);

		s = m.section(form.TypedSection);
		s.anonymous = true;

		s.tab('info', _('Modemdata Info'));
		o = s.taboption('info', ModemDataInfo);

		s.tab('troubleshooting', _('Troubleshooting'));
		o = s.taboption('troubleshooting', Troubleshooting);

		return m.render();
	}
});
