﻿/*
* The contents of this file are subject to the Mozilla Public
* License Version 1.1 (the "License"); you may not use this
* file except in compliance with the License. You may obtain a
* copy of the License at http://www.mozilla.org/MPL/
* 
* Software distributed under the License is distributed on an
* "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, either express
* or implied. See the License for the specific language
* governing rights and limitations under the License.
* 
* The Original Code is 'Movie Masher'. The Initial Developer
* of the Original Code is Doug Anarino. Portions created by
* Doug Anarino are Copyright (C) 2007-2011 Syntropo.com, Inc.
* All Rights Reserved.
*/


package com.moviemasher.type
{
	import com.moviemasher.events.*;
	import flash.events.*;
	import flash.display.*;
	import com.moviemasher.interfaces.*;
/**
* Implementation base class for MovieClips having properties
*/
	public class PropertiedMovieClip extends MovieClip implements IPropertied
	{
		public function PropertiedMovieClip()
		{
			_attributes = new Object();
			_defaults = new Object();
		}
		public function addEventBroadcaster(property:String, broadcaster:IEventDispatcher):void
		{
			broadcaster.addEventListener(property, changeEvent);
		}
		public function changeEvent(event:ChangeEvent):void
		{
			setValue(event.value, event.property);
		}
		public function getValue(property:String):Value
		{
			var value:Value = _attributes[property];
			if (value == null)
			{
				var s:String = '';
				if (_tag != null)
				{
					s = String(_tag.@[property]);
				}
				if ((s.length == 0) && (_defaults != null) && (_defaults[property] != null))
				{
					s = _defaults[property];
				}
				if ((s.length == 0) && hasOwnProperty(property) && (this[property] is IValued) && (this[property] != null))
				{
					value = new Value(this[property]);
				}
				if (value == null)
				{
					value = new Value(s);
				}
			}
			return value;
		}
		public function setValue(value:Value, property:String):Boolean
		{
			if (_tag == null)
			{
				_tag = new XML("<Propertied />");
			}
			_tag.@[property] = value.string;
			_attributes[property] = value.copy();
			return false;
		}
		public function get tag():XML
		{
			return _tag;
		}
		public function set tag(xml:XML):void
		{
			_tag = xml;
			var attributes:XMLList = _tag.attributes();
			var z:int = attributes.length();
			var child:XML;
			for (var i:int = 0; i < z; i++)
			{
				child = attributes[i];
				_attributes[child.name().localName] = new Value(child.toString());
			}
			_parseTag();
		}
		protected function _parseTag():void
		{}
		protected var _tag:XML;
		protected var _defaults:Object;
		protected var _attributes:Object;
	}
}