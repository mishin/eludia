	Ext.BLANK_IMAGE_URL = '/i/0.gif';
	Ext.util.Cookies.set ('ExtJs', 1);
	Ext.Ajax.url        = '/';

	var fio			= null;
	var menu_md5	= '';
	var is_dirty		= 0;
	
	Ext.applyIf (Array.prototype, {

		map : function (fun, scope) {
                
			var len = this.length;

			if (typeof fun != "function") throw new TypeError ();

			var res = new Array (len);

			for (var i = 0; i < len; i++) {

				if (i in this) res [i] = fun.call (scope || this, this [i], i, this);

			}

			return res;

		}		
		
	});

/////////////// CORE

	function nope (url, _target, options) {
	
		if (!ui.sid) {
		
			var m = url.match (/sid\=\d+/);
			
			if (m && m [0]) {

				ui.sid = m [0].substr (4);
				
				return ui.init ();

			}

		}
	
		if (_target == '_self') _target = null;
	
		var target = _target ? _target : ui.panel.center;
		
		if (Ext.isString (target)) {
		
			var component = Ext.ComponentMgr.get (target);
			
			if (component) {target = component};
		
		}
		
		if (Ext.isString (target)) {

			window.open (url, target);

		}
		else {
		
			ui.target = target;

			clear (target);

			Ext.Ajax.request ({

				url: url,

				success: function (response, options) {

					var s = response.responseText;
					
					if (s.substr (0, 20) == '<html><head><script>') {
					
						s = s.replace ('<html><head><script>', '').replace ('</script></head></html>', '');
					
					}

//					try {

						eval (s);

//					}
//					catch (e) {

//						Ext.MessageBox.alert ('������', '<pre>' + e.description + "\n" + s + '</pre>');

//					}

					try { ui.target.show () } catch (e) {}
					
					if (target == ui.panel.center) ui.last_url = url;

				}

			});

			target.doLayout ();

		}

	}
	
	function bodyOnKeyDown (e, t, o) {
	
		if (e.keyCode == 116 && ui.last_url) {
		
			nope (ui.last_url);
		
		}
		else {

			var key = '' +
				(e.ctrlKey  ? 1 : 0) +
				(e.altKey   ? 1 : 0) +
				(e.shiftKey ? 1 : 0) +
				 e.keyCode;

			var d = ui.hotkeys [key];

			if (!d) return;

			eval (d);
		
		}

		try { 
		
			e.browserEvent.keyCode = 32;
	
			e.stopEvent ();
			
		} catch (e) {}

	}

	function sendKeepAliveRequest () {
				
		Ext.Ajax.request ({
					
			url    : '/',
						
			method : 'GET',
						
			params : {keepalive : ui.sid}
					
		});
				
	}

/////////////// FORM

	function submitFormNamed (name) { 
	
		Ext.getDom('__form_' + name).parentNode.submit ();
		
	}

	var checkboxesCheckChange = function (node, checked) {

		Ext.DomQuery.selectNode ("*[name='_" + node.ui.getIconEl ().parentNode.attributes ['ext:tree-node-id'].value + "']").value = checked ? 1 : '';

	}

	var createFieldOfType = {
	
		'select' : function (form, button) {
		
			var values = button.values;
			
			if (button.empty) values.unshift ({id : '', label : button.empty});

			var f = new Ext.form.ComboBox ({

				name  : '__' + button.name,
				hiddenName  : '_' + button.name,

				store: new Ext.data.JsonStore ({
					id: 0,
					fields: ['id', 'label'],
					autoDestroy  : true,
					data: values
				}),

				valueField: 'id',
				fieldLabel: button.label,
				displayField: 'label',
				width: '100%',
				mode: 'local',
				editable: false,
				triggerAction: 'all'

			});

			var max = 0;

			for (var j = 0; j < values.length; j ++) {

				var v = values [j];

				var l = v.label.length;

				if (max < l) max = l;

				if (v.selected) {

					f.setValue (v.id);

					break;

				}

			}

			f.setWidth (10 * max);

			return f;
		
		},
		
		'checkboxes' : function (form, button) {
		
			var node = new Ext.tree.TreeNode ();

			var width = 100;

			for (var i = 0; i < button.values.length; i ++) {
			
				var v = button.values [i];
				
				var l = v.label;
				
				form.add (new Ext.form.Hidden ({name: '_' + button.name + '_' + v.id, value: v.checked}));
										
				var w = 34 + 7 * l.length;

				if (width < w) width = w;
									
				node.appendChild ({

					id: button.name + '_' + v.id,
					text: l,							
					leaf: true,
					iconCls :'no-icon',
					checked: (v.checked == 1)
				
				});
			
			}

			return {
			
				xtype:'treepanel',
				fieldLabel: button.label,
				autoScroll: true,
				animate: true,
				lines: false,
				containerScroll: true,
				border: false,
				rootVisible: false,
				height: button.height ? button.height : 150,
			        margins: '5 0 5 5',
			        width:width,
				root: node,
				listeners : {
				
					checkchange : checkboxesCheckChange
				
				}

			};

		},
	
		'static' : function (form, button) {

			return new Ext.form.DisplayField ({
				fieldLabel : button.label,
				value      : button.value
			});

		},
		
		'string' : function (form, button) {

			return new Ext.form.TextField ({
				name       : '_' + button.name,
				fieldLabel : button.label,
				value      : button.value
			});

		},
		
		'date' : function (form, button) {

			return new Ext.form.DateField ({
				name       : '_' + button.name,
				fieldLabel : button.label,
				format     : button.format,
				value      : button.value
			});

		},
		
		'hgroup' : function (form, button) {
		
			addFields (form, button.items);

		}

	};
	
	function addFields (form, buttons) {
	
		var a = [];
		
		for (var i = 0; i < buttons.length; i ++) {
		
			var button = buttons [i];
			
			var createField = createFieldOfType [button.type];
		
			if (!createField) continue;
			
			var f = createField (form, button);
			
			if (!f) continue;
			
			a.push (f);

		}

		if (!a.length) return;
				
		form.add ([a]);

	}
	
	var toolbarButtonHandler = function (b, e) {
	
		eval (b.__handler_source);
	
	}
	
	function createToolbarButton (options) {
	
		var button = new Ext.Button ({

			text: options.label,
			
			__handler_source: options.handler,
			
			handler : toolbarButtonHandler

		});
		
		return button;
	
	}

	function createFormPanel (options) {
			
		var formOptions = {
		
			frame:true,
			title: '',
			layout: 'form',
			buttonAlign  : 'center',

			labelWidth: 200,
			labelSeparator: ' ',

			defaults: {width: 230},
			id: '__form_' + options.name,
			
			autoScroll: true,

			listeners : {
			
				afterrender : function (_this) {
				
					var f = _this.getEl ().dom.parentNode;
					
					f.enctype = f.encoding = 'multipart/form-data';					
					f.target  = 'invisible';

				}

			}                    

		};
		
		if (options.path) formOptions.title = options.path.map (function (i) {return i.label}).join (' / ');
			
		var form = new Ext.Panel (formOptions);
		
		Ext.each (options.bottom_toolbar, function (i) {form.addButton (createToolbarButton (i))});

		form.add (new Ext.form.Hidden ({name: '__iframe_target', value: 1}));
		
		for (var r = 0; r < options.rows.length; r ++) {
		
			var buttons = options.rows [r];

			addFields (form, buttons);
					
		}

		for (var k = 0; k < options.keep_params.length; k ++) {
		
			var kp = options.keep_params [k];
		
			form.add (new Ext.form.Hidden ({name: kp.name, value: kp.value}));
		
		}

		return form;
	
	}

/////////////// TABLE

	function adjust_column_widths (columns, data) {

		for (var i = 0; i < columns.length; i ++) {

			var c = columns [i];

			if (c.width > 0) continue;

			c.width = 1;

			for (var j = 0; j < data.length; j ++) {

				var r = data [j];

				var d = r ['f' + i];

				if (d == null || d == '') continue;

				var w = 7 * d.length;

				if (c.width < w) c.width = w;

			}

		}

	}
	
	function createGridToolbar (buttons, store) {
	
		var tb = new Ext.Toolbar ({
			
		});
		
		for (var i = 0; i < buttons.length; i ++) {
		
			var button = buttons [i];
			
			if (button.type == 'button') {
			
				if (!button.target) button.target = 'invisible';
			
				var f = new Ext.Button ({
				
					text    : button.label,
					
					href    : button.href,
					
					handler :

						button.href.charAt (0) == 'j' ? function (b) {eval (b.href.substr (11))} :

						button.target == 'invisible'  ? function (b) {document.frames ['invisible'].location.href = b.href} :

						                                function (b) {nope (b.href, b.target);}

				});

				tb.add (f);

			}
			else if (button.type == 'input_text') {

				if (button.label) tb.add (button.label + ': ');

				var f = new Ext.form.TextField ({
				
					name  : button.name,
					value : button.value,
					grow  : true,
					width : 30,

					enableKeyEvents : true,

					listeners       : {

						afterRender : function () {

							if (Ext.isIE6 || Ext.isIE7) {
								this.el.setY(1 + this.el.getY());
							}

						},

						keyup : function (_this, _e) {
						
							if (store.baseParams [_this.name] == _this.getValue ()) return;

							store.setBaseParam (_this.name, _this.getValue ());
							
							store.load ({});

						}

					}
				
				});
				
				tb.add (f);
				
			}
			else if (button.type == 'input_date') {

				if (button.label) tb.add (button.label + ': ');

				var f = new Ext.form.DateField ({
				
					name   : button.name,
					format : button.format,
					value  : button.value,
					width  : 80,

					listeners       : {

						afterRender : function () {

							if (Ext.isIE6 || Ext.isIE7) {
								this.el.setY(2 + this.el.getY());
								this.trigger.setY(1 + this.trigger.getY());
							}

						},

						select : function (_this, _e) {
						
							if (store.baseParams [_this.name] == _this.getValue ()) return;

							store.setBaseParam (_this.name, _this.getValue ());
							
							store.load ({});

						}

					}
				
				});

				tb.add (f);

			}
			else if (button.type == 'input_select') {
			
				var values = button.values;


				var f = new Ext.form.ComboBox ({
				
					name  : button.name,

					store: new Ext.data.JsonStore ({
						id: 0,
						autoDestroy  : true,
						fields: ['id', 'label'],
						data: values
					}),
					
					valueField: 'id',
					displayField: 'label',
					mode: 'local',
					editable: false,
					triggerAction: 'all',

					listeners       : {
					
						afterRender : function () {

							if (Ext.isIE6 || Ext.isIE7) {
								this.el.setY(2 + this.el.getY());
								this.trigger.setY(1 + this.trigger.getY());
							}

						},

						select : function (_this, record, index) {

								if (store.baseParams [_this.name] == _this.getValue ()) return;

								store.setBaseParam (_this.name, _this.getValue ());

								store.load ({});

							}

						}
				
					}
					
				);
				
				var max = 0;
				
				for (var j = 0; j < values.length; j ++) {
				
					var v = values [j];
					
					var l = v.label.length;
					
					if (max < l) max = l;
					
					if (v.selected) {
					
						f.setValue (v.id);
						
						break;
					
					}
				
				}
				
				f.setWidth (10 * max);
				
				tb.add (f);

			}
		
		}
		
		return tb;

	};
	
	var tableStoreLoaded = function (jsonStore) {
			
		var data = jsonStore.reader.jsonData;
		
		cell_hrefs = data.cell_hrefs;
		
		data.href = [];
		
		for (href in cell_hrefs) {
		
			var full_href = data.cell_href_prefix + href;
					
			var list = cell_hrefs [href];
			
			for (var i = 0; i < list.length; i ++) {
			
				var c = list [i];
				
				var r = c [0] - 1;
				
				if (!data.href [r]) data.href [r] = [];
				
				data.href [r] [c [1]] = full_href;
			
			}
		
		}
	
	}
	



Ext.ux.EludiaGridPanel = Ext.extend (Ext.grid.GridPanel, {

    processEvent : function(name, e){
        this.fireEvent(name, e);
        var t = e.getTarget(),
            v = this.view,
            header = v.findHeaderIndex(t);
            
        if(header !== false){
            this.fireEvent('header' + name, this, header, e);
        }else{
            var row = v.findRowIndex(t),
                cell,
                body;
            if(row !== false){
                this.fireEvent('row' + name, this, row, e);
                cell = v.findCellIndex(t);
                body = v.findRowBody(t);
                if(cell !== false){
                    this.fireEvent('cell' + name, this, row, cell, e);
                }
                if(body){
                    this.fireEvent('rowbody' + name, this, row, e);
                }
            }else{
                this.fireEvent('container' + name, this, e);
            }
        }
	if (this.view) this.view.processEvent(name, e);
    }

});

	var tableCellClicked = function (grid, row, col, e) {
	
		var href = grid.store.reader.jsonData.href [row] [col];

/*		
		ui.target = new Ext.Window ({
		
			layout:'fit',
			modal:true,
			width:500,
			height:300
		
		});
*/		
				
		if (href) nope (href, ui.target);
			
	}

	function createGridPanel (data, columns, storeOptions, fields, panelOptions, base_params, buttons, scrollable_table_row) {

		adjust_column_widths (columns, data.root);

		storeOptions.fields      = fields;
		storeOptions.root        = 'root';
		storeOptions.autoDestroy = true,
		storeOptions.data        = data;
		storeOptions.url         = '/';
		storeOptions.baseParams  = base_params;

		panelOptions.store    = new Ext.data.JsonStore (storeOptions);
		tableStoreLoaded      (panelOptions.store);
		panelOptions.store.on ('load', tableStoreLoaded);
		
		panelOptions.colModel = new Ext.grid.ColumnModel ({columns: columns});
		panelOptions.sm       = new Ext.grid.RowSelectionModel ({singleSelect:true});
		
		panelOptions.sm.on ('rowselect', function (m, i, r) {
		
			m.lastSelectedRow = i;

		});

		if (buttons.length > 0)	panelOptions.tbar = createGridToolbar (buttons, panelOptions.store);
		
		if (!panelOptions.listeners) panelOptions.listeners = {};
		if (!panelOptions.listeners.cellclick) panelOptions.listeners.cellclick = tableCellClicked;

		if (data.total) {

			panelOptions.bbar     = new Ext.PagingToolbar ({
				store    : panelOptions.store,
				pageSize : data.cnt
			});

		}
		
		var grid = new Ext.ux.EludiaGridPanel (panelOptions);
		
		grid.on ("render", function () {
		
			try {
		
				grid.getSelectionModel ().selectRow (scrollable_table_row);
			
				grid.getView ().focusRow (scrollable_table_row);
			
			}
			catch (e) {}

		}, grid, {delay: 200});

		grid.on ("keydown", function (e) {
		
			if (e.keyCode == 13) {
			
				tableCellClicked (grid, grid.getSelectionModel ().lastSelectedRow, 0, e);
						
			}

		}, grid, {});

		return grid;

	}

/////////////// MENU

	function createSubMenuItem (m) {

		if (m == 'BREAK') return new Ext.menu.Separator ({});

		return new Ext.menu.Item ({

			text    : m.label,
			options : m,
			handler : menuButtonHandler

		});

	}

	var menuButtonHandler = function (b, e) {

		var options = b.options;

		if (options.no_page) return;

		if (options.name) {

			var href = '/?sid=' + ui.sid + '&type=' + b.options.name;

			href += '&_salt=' + Math.random ();

			nope (href);

		}

	}

	function createMenuButton (mi) {

		var b = new Ext.Button ({

			text    : mi.label.replace ("&", ""),
			options : mi,
			handler : menuButtonHandler

		});

		var ii = mi.items;

		if (!ii) return b;

		var sm = new Ext.menu.Menu ({
			plain: true,
			showSeparator  : false
		});

		for (var j = 0; j < ii.length; j ++) sm.add (createSubMenuItem (ii [j]));

		b.menu = sm;

		return b;

	}

	function clear (container) {
	
		container.removeAll (true);
		
		if (container == ui.panel.center) is_dirty = 0;

	}

	function createMenu (tb, m, showFirstPage) {

		clear (tb);

		for (var i = 0; i < m.length; i ++) {

			if (m [i].off) continue;

			var button = createMenuButton (m [i]);

			tb.add (button);

			if (!showFirstPage) continue;

			menuButtonHandler (button, null);

			showFirstPage = false;

		}

		tb.doLayout ();

	}
	
/////////////// MISC

	var applicationExit = function (e) {

		Ext.MessageBox.confirm (

			'���������� ������',

			'�� �������, ��� ������ ��������� ������ � �����������?',

			function (btn) { if (btn == 'yes') window.close () }

		);

	}