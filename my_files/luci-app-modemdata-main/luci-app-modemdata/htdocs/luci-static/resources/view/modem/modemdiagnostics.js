'use strict';
'require baseclass';
'require form';
'require fs';
'require uci';
'require ui';
'require view';
'require tools.widgets as widgets';

/*

  Copyright 2025 Rafał Wabik - IceG - From eko.one.pl forum

  MIT License
  
*/

let commandOutputDialog = baseclass.extend({
  __init__: function(title, content){ this.title = title; this.content = content; },

  render: function(){
    let self = this;

    ui.showModal(this.title, [
      E('p', _('Command result')),
      E('textarea', {
        'id': 'cmd_modal_output',
        'class': 'cbi-input-textarea',
        'style': 'width:100% !important; height:60vh; min-height:500px;',
        'readonly': true,
        'wrap': 'off',
        'spellcheck': 'false'
      }, this.content.trim()),

      E('div', { 'class': 'right' }, [
        E('button', {
          'class': 'btn cbi-button-remove',
          'click': ui.createHandlerFn(this, function(){
            document.getElementById('cmd_modal_output').value = '';
            fs.write('/tmp/debug_result.txt', '')
              .catch(function(e){
                ui.addNotification(null, E('p', _('Unable to clear the file') + ': %s'.format(e.message)), 'error');
              });
          })
        }, _('Clear')), ' ',

        E('button', {
          'class': 'cbi-button cbi-button-apply important',
          'click': ui.createHandlerFn(this, function(){
            let blob = new Blob([self.content], { type: 'text/plain' });
            let link = document.createElement('a');
            link.download = 'debug_result.txt';
            link.href = URL.createObjectURL(blob);
            link.click();
            URL.revokeObjectURL(link.href);
          })
        }, _('Download')), ' ',

        E('button', {
          'class': 'btn',
          'click': ui.hideModal
        }, _('Close'))
      ])
    ], 'cbi-modal');
  },

  show: function(){ this.render(); }
});

return view.extend({
  handleCommand: function(exec, args){
    return fs.exec(exec, args).then((res)=>{
      let output = [res.stdout||'', res.stderr||''].join('\n');
      fs.write('/tmp/debug_result.txt', res.stdout||'');
      let dialog = new commandOutputDialog(_('Diagnostics'), output);
      dialog.show();
    }).catch((err)=>{ ui.addNotification(null, E('p', [err])); }).finally(()=>{});
  },

  handleUSB: function(){ return this.handleCommand('/bin/cat', ['/sys/kernel/debug/usb/devices']); },
  handleTTY: function(){ return this.handleCommand('/bin/ls', ['/dev']); },

  handleDBG: function(){
    let select = document.getElementById('mselect'); let value = select ? select.value : '';
    let valueParts = value.split('_'); let device = valueParts[1] || ''; let network = valueParts[2] || '';
    return this.handleCommand('/bin/sh', ['/usr/bin/md_serial_ecm', device, network]);
  },

  handleproduct: function(){
    let select = document.getElementById('mselect'); let value = select ? select.value : '';
    let device = value.split('_')[1] || '';
    return this.handleCommand('/bin/sh', ['-x', '/usr/share/modemdata/product.sh', device]);
  },

  handlenetwork: function(){
    let select = document.getElementById('mselect'); let value = select ? select.value : '';
    let network = value.split('_')[2] || '';
    return this.handleCommand('/bin/sh', ['-x', '/usr/share/modemdata/network.sh', network]);
  },

  handleparams: function(){
    let select = document.getElementById('mselect'); let value = select ? select.value : '';
    let device = value.split('_')[1] || '';
    return this.handleCommand('/bin/sh', ['-x', '/usr/share/modemdata/params.sh', device]);
  },

  handleuqmi: function(){
    let select = document.getElementById('mselect'); let value = select ? select.value : '';
    let valueParts = value.split('_'); let device = valueParts[1]||''; let network = valueParts[2]||''; let forced_plmn = valueParts[3]||''; let onproxy = (valueParts[4]||'').replace('undefined','0');
    return this.handleCommand('/bin/sh', ['/usr/bin/md_uqmi', device, network, forced_plmn, onproxy]);
  },

  handleparuqmi: function(){
    let select = document.getElementById('mselect'); let value = select ? select.value : '';
    let valueParts = value.split('_'); let device = valueParts[1]||''; let forced_plmn = valueParts[3]||''; let onproxy = (valueParts[4]||'').replace('undefined','0');
    return this.handleCommand('/bin/sh', ['-x', '/usr/share/modemdata/params_qmi.sh', device, forced_plmn, onproxy]);
  },

  handlemm: function(){
    let select = document.getElementById('mselect'); let value = select ? select.value : '';
    let valueParts = value.split('_'); let device = valueParts[1]||''; let network = valueParts[2]||''; let forced_plmn = valueParts[3]||'';
    return this.handleCommand('/bin/sh', ['/usr/bin/md_modemmanager', device, network, forced_plmn]);
  },

  handleparamsmm: function(){
    let select = document.getElementById('mselect'); let value = select ? select.value : '';
    let valueParts = value.split('_'); let device = valueParts[1]||''; let forced_plmn = valueParts[3]||'';
    return this.handleCommand('/bin/sh', ['-x', '/usr/share/modemdata/params_modemmanager.sh', device, forced_plmn]);
  },

  handleprodmm: function(){
    let select = document.getElementById('mselect'); let value = select ? select.value : '';
    let valueParts = value.split('_'); let device = valueParts[1]||'';
    return this.handleCommand('/bin/sh', ['-x', '/usr/share/modemdata/product_modemmanager.sh', device]);
  },

  handleClear: function(){ fs.write('/tmp/debug_result.txt',''); },

  handleDownload: function(){
    return L.resolveDefault(fs.read_direct('/tmp/debug_result.txt'), null).then((res)=>{
      if(res){ let blob = new Blob([res], { type:'text/plain' }); let link = document.createElement('a'); link.download = 'debug_result.txt'; link.href = URL.createObjectURL(blob); link.click(); URL.revokeObjectURL(link.href); }
    }).catch((err)=>{ ui.addNotification(null, E('p', {}, _('Download error') + ': ' + err.message)); });
  },

  handleBlock: function(){
    let select = document.getElementById('mselect'); let value = select ? select.value : ''; let valueParts = value.split('_'); let modemdata = valueParts[0] || '';
    let buttons = document.querySelectorAll('.diag-action > .cbi-button'); for(let i=0;i<buttons.length;i++) buttons[i].removeAttribute('disabled');

    if (modemdata.includes('uqmi')) { 
        document.getElementById('s1').setAttribute('disabled','disabled');
        document.getElementById('s2').setAttribute('disabled','disabled');
        document.getElementById('s3').setAttribute('disabled','disabled');
        document.getElementById('m1').setAttribute('disabled','disabled');
        document.getElementById('m2').setAttribute('disabled','disabled');
        document.getElementById('m3').setAttribute('disabled','disabled');
    }
    if (modemdata.includes('serial')) {
        document.getElementById('u1').setAttribute('disabled','disabled');
        document.getElementById('u2').setAttribute('disabled','disabled');
        document.getElementById('m1').setAttribute('disabled','disabled');
        document.getElementById('m2').setAttribute('disabled','disabled');
        document.getElementById('m3').setAttribute('disabled','disabled');
    }
    if (modemdata.includes('mm')) {
        document.getElementById('s1').setAttribute('disabled','disabled');
        document.getElementById('s2').setAttribute('disabled','disabled');
        document.getElementById('s3').setAttribute('disabled','disabled');
        document.getElementById('u1').setAttribute('disabled','disabled');
        document.getElementById('u2').setAttribute('disabled','disabled');
    }
  },

  load: function(){ return L.resolveDefault(uci.load('defmodems')); },

  render: function(){
    let sections = uci.sections('defmodems','defmodems');
    let result = sections.map(s=>`${s.modemdata}_${s.comm_port}_${s.network}_${s.forced_plmn}_${s.onproxy}_#[ ${s.modemdata} ] ${s.comm_port} - ${s.modem} (${s.user_desc})`).join(';');
    result = result.replace("(undefined)","");

    let off_s1,off_s2,off_s3,off_u1,off_u2,off_m1,off_m2,off_m3;
    let modemz = E('div', { class:'cbi-section' }, [
      E('div', { class:'cbi-section-descr' }, this.description),
      E('div', { class:'cbi-value' }, [
        E('label', { class:'cbi-value-title' }, [_('Modem')]),
        E('div', { class:'cbi-value-field' }, [
          E('select', { class:'cbi-input-select', id:'mselect', style:'width:100%;', change:ui.createHandlerFn(this,'handleBlock'), mousedown:ui.createHandlerFn(this,'handleBlock') },
            (result||'').trim().split(/;/).map(function(cmd){ let fields = cmd.split(/#/); let name = fields[1]; let code = fields[0]; return E('option', { value:code }, name); })
          )
        ])
      ])
    ]);

    let modemdata = result.split('_')[0] || '';
    if (modemdata.includes('uqmi')) {
    const ids=['s1','s2','s3','m1','m2','m3'];
        off_s1=ids.includes('s1')?true:false;
        off_s2=ids.includes('s2')?true:false;
        off_s3=ids.includes('s3')?true:false;
        off_m1=ids.includes('m1')?true:false;
        off_m2=ids.includes('m2')?true:false;
        off_m3=ids.includes('m3')?true:false;
    }
    if (modemdata.includes('serial')) {
    const ids=['u1','u2','m1','m2','m3'];
        off_u1=ids.includes('u1')?true:false;
        off_u2=ids.includes('u2')?true:false;
        off_m1=ids.includes('m1')?true:false;
        off_m2=ids.includes('m2')?true:false;
        off_m3=ids.includes('m3')?true:false;
    }
    if (modemdata.includes('mm')) {
    const ids=['s1','s2','s3','u1','u2'];
        off_s1=ids.includes('s1')?true:false;
        off_s2=ids.includes('s2')?true:false;
        off_s3=ids.includes('s3')?true:false;
        off_u1=ids.includes('u1')?true:false;
        off_u2=ids.includes('u2')?true:false;
    }

    let table4 = E('table', { class:'table', style:'width:100%; table-layout:fixed; margin-top:1em;' }, [
      E('tr', {}, [
        E('td', { class:'td left', style:'vertical-align:top; width:33%;' }, [
          E('label', { class:'cbi-value-title' }, _("USB debug information")),
          E('p', {}, _("<code>cat /sys/kernel/debug/usb/devices</code>")),
          E('span', { class:'diag-action' }, [ E('button', { class:'cbi-button', click:ui.createHandlerFn(this,'handleUSB') }, _('Run')) ])
        ]),
        E('td', { class:'td left', style:'vertical-align:top; width:33%;' }, [
          E('label', { class:'cbi-value-title' }, _("Check ttyX ports")),
          E('p', {}, _("<code>ls /dev</code>")),
          E('span', { class:'diag-action' }, [ E('button', { class:'cbi-button', click:ui.createHandlerFn(this,'handleTTY') }, _('Run')) ])
        ]),
        E('td', { class:'td left', style:'vertical-align:top; width:33%;' }, [
          E('label', { class:'cbi-value-title' }, _("Check") + ' ' + _("network.sh")),
          E('p', {}, _("<code>sh -x /usr/share/modemdata/network.sh</code>")),
          E('span', { class:'diag-action' }, [ E('button', { class:'cbi-button', click:ui.createHandlerFn(this,'handlenetwork') }, _('Run')) ])
        ])
      ])
    ]);

    let table = E('table', { class:'table', style:'width:100%; table-layout:fixed;' }, [
      E('tr', {}, [
        E('td', { class:'td left', style:'vertical-align:top; width:33%;' }, [
          E('label', { class:'cbi-value-title' }, _("Check serial and ecm mode")),
          E('p', {}, _("<code>sh /usr/bin/md_serial_ecm</code>")),
          E('span', { class:'diag-action' }, [ E('button', { class:'cbi-button cbi-button-add', id:'s1', disabled:off_s1, click:ui.createHandlerFn(this,'handleDBG') }, _('Run')) ])
        ]),
        E('td', { class:'td left', style:'vertical-align:top; width:33%;' }, [
          E('label', { class:'cbi-value-title' }, _("Check") + ' ' + _("product.sh")),
          E('p', {}, _("<code>sh -x /usr/share/modemdata/product.sh</code>")),
          E('span', { class:'diag-action' }, [ E('button', { class:'cbi-button cbi-button-add', id:'s2', disabled:off_s2, click:ui.createHandlerFn(this,'handleproduct') }, _('Run')) ])
        ]),
        E('td', { class:'td left', style:'vertical-align:top; width:33%;' }, [
          E('label', { class:'cbi-value-title' }, _("Check") + ' ' + _("params.sh")),
          E('p', {}, _("<code>sh -x /usr/share/modemdata/params.sh</code>")),
          E('span', { class:'diag-action' }, [ E('button', { class:'cbi-button cbi-button-add', id:'s3', disabled:off_s3, click:ui.createHandlerFn(this,'handleparams') }, _('Run')) ])
        ])
      ])
    ]);

    let table2 = E('table', { class:'table', style:'width:100%; table-layout:fixed; margin-top:1em;' }, [
      E('tr', {}, [
        E('td', { class:'td left', style:'vertical-align:top; width:33%;' }, [
          E('label', { class:'cbi-value-title' }, _("Check uqmi mode")),
          E('p', {}, _("<code>sh -x /usr/bin/md_uqmi</code>")),
          E('span', { class:'diag-action' }, [ E('button', { class:'cbi-button cbi-button-remove', id:'u1', disabled:off_u1, click:ui.createHandlerFn(this,'handleuqmi') }, _('Run')) ])
        ]),
        E('td', { class:'td left', style:'vertical-align:top; width:33%;' }, [
          E('label', { class:'cbi-value-title' }, _("Check") + ' ' + _("params_qmi.sh")),
          E('p', {}, _("<code>sh -x /usr/share/modemdata/params_qmi.sh</code>")),
          E('span', { class:'diag-action' }, [ E('button', { class:'cbi-button cbi-button-remove', id:'u2', disabled:off_u2, click:ui.createHandlerFn(this,'handleparuqmi') }, _('Run')) ])
        ]),
        E('td', { class:'td left', style:'vertical-align:top; width:33%;' }, [])
      ])
    ]);

    let table3 = E('table', { class:'table', style:'width:100%; table-layout:fixed; margin-top:1em;' }, [
      E('tr', {}, [
        E('td', { class:'td left', style:'vertical-align:top; width:33%;' }, [
          E('label', { class:'cbi-value-title' }, _("Check ModemManager mode")),
          E('p', {}, _("<code>sh -x /usr/bin/md_modemmanager</code>")),
          E('span', { class:'diag-action' }, [ E('button', { class:'cbi-button cbi-button-apply', id:'m1', disabled:off_m1, click:ui.createHandlerFn(this,'handlemm') }, _('Run')) ])
        ]),
        E('td', { class:'td left', style:'vertical-align:top; width:33%;' }, [
          E('label', { class:'cbi-value-title' }, _("Check") + ' ' + _("params_modemmanager.sh")),
          E('p', {}, _("<code>sh -x /usr/share/modemdata/params_modemmanager.sh</code>")),
          E('span', { class:'diag-action' }, [ E('button', { class:'cbi-button cbi-button-apply', id:'m2', disabled:off_m2, click:ui.createHandlerFn(this,'handleparamsmm') }, _('Run')) ])
        ]),
        E('td', { class:'td left', style:'vertical-align:top; width:33%;' }, [
          E('label', { class:'cbi-value-title' }, _("Check") + ' ' + _("product_modemmanager.sh")),
          E('p', {}, _("<code>sh -x /usr/share/modemdata/product_modemmanager.sh</code>")),
          E('span', { class:'diag-action' }, [ E('button', { class:'cbi-button cbi-button-apply', id:'m3', disabled:off_m3, click:ui.createHandlerFn(this,'handleprodmm') }, _('Run')) ])
        ])
      ])
    ]);

    let info = _('For more information about the modemdata package, please visit: %shttps://github.com/obsy/modemdata%s.').format('<a href="https://github.com/obsy/modemdata" target="_blank">','</a>');
    return E('div', { class:'cbi-map' }, [
      E('h2', {}, _('Diagnostics')),
      E('div', { class:'cbi-map-descr' }, _('Run various commands to verify data read from the modem and debug scripts.') + '<br>' + info),
      E('hr'), modemz, table4, table, table2, table3
    ]);
  },

  handleSaveApply: null,
  handleSave: null,
  handleReset: null
});
