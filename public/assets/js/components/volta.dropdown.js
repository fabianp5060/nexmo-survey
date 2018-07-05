/**
 * Copyright (c) 2001-present, Vonage.
 *	
 * Dropdowns (requires core)
 */

'use strict';

Volta.dropdown = function () {	
	var _class = {
		wrapper: 'Vlt-dropdown',
		btn: 'Vlt-dropdown__btn',
		dismissed: 'Vlt-callout--dismissed',
		expanded: 'Vlt-dropdown--expanded',
		panel: 'Vlt-dropdown__panel',
		panelContent: 'Vlt-dropdown__panel__content',
		selection: 'Vlt-dropdown__selection'
	}

	function Dropdown() {}

	Dropdown.prototype = {
		init: function(element, supressClickHandler) {
			this.dropdown = element;
			this.selection = this.dropdown.querySelector('.' + _class.selection);
			this.isSelectionVisible = !!this.selection;
			this.btn = this.dropdown.querySelector('.' + _class.btn);
			this._suppress = supressClickHandler;

			if(!this._suppress) {
				this._addEventListener();
			}
		},
		_addEventListener: function(){
			var openHandler = this.open.bind(this);
			this.dropdown.addEventListener('click', openHandler, { once: true })
		},
		close: function(text) {
			if(text) {
				this._setDropdownSelectionText(text);
			}
			this.dropdown.classList.remove(_class.expanded);

			if(!this._suppress){
				this._addEventListener();
			}
			
		},
		_closeEventHandler: undefined,
		_closeEvent: function(e) {
			var targetIsPanel = Volta._hasClass(e.target, _class.panel);
			var parentIsPanel = Volta._hasClass(e.target.parentElement.parentElement, _class.panelContent);
			
			if(!targetIsPanel && !parentIsPanel) {
				e.preventDefault();
				e.stopPropagation();
			} 

			var text = parentIsPanel ? e.target.innerHTML : undefined;

			this.close(text);

			document.querySelector('body').removeEventListener('click', this._closeEventHandler );
		},
		open: function(event) {
			if(event) {
				event.preventDefault();
				event.stopPropagation();
			}

			this.dropdown.classList.add(_class.expanded);

			if(!this._suppress){
				this._closeEventHandler = this._closeEvent.bind(this);
				document.querySelector('body').addEventListener('click', this._closeEventHandler );
			}			
		},
		_setDropdownSelectionText: function(text) {
			if(this.isSelectionVisible) {
				this.selection .innerText = text;
			} else {
				this.btn.innerText = text;
				this.btn.value = text;
			}
		},
		_suppress: false
	}

	return {
		create: create,
		init: attachDropdownHandlers
	}

	/**   
	 *	@public
	 *	
	 *	@description Attach a listeners to dropdowns
	 */
	function attachDropdownHandlers() {
		document.querySelectorAll('.' + _class.wrapper).forEach(attachHandler);
		
		function attachHandler(dropdown) {
			create(dropdown);
		}
	}

	/**   
	 *	@private
	 *	
	 *	@description Create a dropdown element
	 *  @param {HTMLElement} element 
 	 */
	function create(element){
		var dropdown = Object.create(Dropdown.prototype, {})
		dropdown.init(element);
		return dropdown;
	}
}();