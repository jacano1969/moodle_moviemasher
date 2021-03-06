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

package com.moviemasher.core
{
	import com.moviemasher.events.*;
	import com.moviemasher.display.*;
	import com.moviemasher.interfaces.*;
	import com.moviemasher.type.*;
	import com.moviemasher.constant.*;
	import com.moviemasher.utils.*;
	import flash.display.*;
	import flash.events.*;
	import flash.geom.*;
	import flash.system.*;
	import flash.utils.*;

/**
* Implementation class represents an instance of a {@link IMedia} item, usually within a mash.
* 
* @see IClip
*/
	public class Clip extends Propertied implements IClip
	{
		public function Clip(type:String, media:IMedia, mash:IMash = null)
		{
			
			__composites = new Vector.<IClip>(); 
			__effects = new Vector.<IClipEffect>(); 
		
		
			__media = media;
			__type = type;
			__mash = mash;
		}
/**
* Static function creates clip out of {@link IMedia} object.
* 
* @param media IMedia object that clip is instance of.
* @param xml XML object containing clip or media tag or null,
* @param mash IMash object that will hold clip or null.
* @returns IClip ready for inserting into mash or null if media is null or has no type.
*/
		public static function fromMedia(media:IMedia, xml:XML = null, mash:IMash = null):IClip
		{
			var item_ob:IClip = null;
			try
			{
				if (media != null)
				{
					var media_id:String = media.getValue(CommonWords.ID).string;
					var type:String = media.getValue(CommonWords.TYPE).string;
					if (type.length)
					{
						switch(type)
						{
							case ClipType.TRANSITION:
								item_ob = new TransitionClip(type, media, mash);
								break;
							case ClipType.EFFECT:
								item_ob = new EffectClip(type, media, mash);
								break;
							default:
								item_ob = new Clip(type, media, mash);
					
						}
						if (item_ob != null)
						{
							if (xml == null) 
							{
								xml = new XML('<clip type="' + type + '" id="' + media_id + '" />');
								var composites:Value = media.getValue(ClipProperty.COMPOSITES);
								if (! composites.empty)
								{
									var a:Array = composites.array;
									var z:uint = a.length;
									for (var i:uint = 0; i < z; i++)
									{
										media_id = a[i];
										media = RunClass.Media['fromMediaID'](media_id, mash);
										if (media != null)
										{
											type = media.getValue(CommonWords.TYPE).string;
											xml.appendChild(new XML('<clip type="' + type + '" id="' + media_id + '" track="' + (i - z) + '" />'));
										}
									}
								}
							}
							item_ob.tag = xml.copy();
						}
					}
				}
			}
			catch(e:*)
			{
				RunClass.MovieMasher['msg'](Clip, e);
			}
			return item_ob;
		}
/**
* Static function creates clip out of Media ID.
* 
* @param id String containing {@link Media} object identifier
* @param xml XML object containing clip or media tag or null,
* @param mash IMash object that will hold clip or null.
* @returns IClip ready for inserting into mash or null if media wasn't found.
*/
		public static function fromMediaID(id:String, xml:XML = null, mash:IMash = null):IClip
		{
			var item_ob:IClip = null;
			var media:IMedia;
			try
			{
				media = RunClass.Media['fromMediaID'](id, mash);
				
				if ((media == null) && (xml != null))
				{
					//RunClass.MovieMasher['msg']('Clip.fromMediaID using XML ' + xml.toXMLString());
					media = RunClass.Media['fromXML'](xml);
				}
				if (media != null)
				{
					item_ob = fromMedia(media, xml, mash);
				}
				
			}
			catch(e:*)
			{
				RunClass.MovieMasher['msg'](Clip, e);
			}
			return item_ob;
		}
/**
* Static function creates clip out of media or clip tag.
* 
* @param xml XML object containing clip or media tag or null,
* @param mash IMash object that will hold clip or null.
* @param media IMedia object or null to force search for one with id matching xml's id attribute.
* @returns IClip ready for inserting into mash or null if media wasn't found.
*/
		public static function fromXML(node:XML, mash:IMash = null, media:IMedia = null):IClip
		{ 
			var clip:IClip = null;
			if (media != null) clip = fromMedia(media, node, mash);
			else clip = fromMediaID(String(node.@id), node, mash);
			return clip;
		}
		public function changeQuantization(old_q:int, new_q:int):void
		{
			if (old_q != new_q)
			{
				switch(type)
				{
					case ClipType.AUDIO:
					case ClipType.VIDEO:
						// adjust trimming
						__startTrimFrame = RunClass.TimeUtility['convertFrame'](__startTrimFrame, old_q, new_q);
						__endTrimFrame = RunClass.TimeUtility['convertFrame'](__endTrimFrame, old_q, new_q);
						break;
				}
				__lengthFrame = RunClass.TimeUtility['convertFrame'](__lengthFrame, old_q, new_q);
			}
		}
/**
* Causes loading of clip assets.
* 
* @param first int describing start time to buffer
* @param last int describing end time to buffer
* @param mute Boolean object indicating whether or not sound is needed
*/
		public function buffer(first:Number, last:Number, mute:Boolean, rebuffer:Boolean):void
		{
			//RunClass.MovieMasher['msg'](this + '.buffer ' + first + '->' + last + ' mute = ' + mute);
			try
			{
				__mute = mute;
				
				var media_range:Object = __mediaRange(first, last);
				if (_module == null)
				{
					__requestModule();
				}
				if (_module != null)
				{
					_module.buffer(media_range.start, media_range.end, __mute || (! __hasA()), rebuffer);
				}

					
				var z:uint = __effects.length;
				if (z)
				{
					var clip:IClipEffect;
					for (var i:uint = 0; i < z; i++)
					{
						clip = __effects[i];
						clip.buffer(media_range.start, media_range.end, __mute || (! __hasA()), rebuffer);
					}
				}

			}
			catch(e:*)
			{
				RunClass.MovieMasher['msg'](this + '.buffer', e);
			}
		}
/**
* See whether or not a time range is loaded and ready for display.
* 
*
* @param first int describing start time to buffer
* @param last int describing end time to buffer
* @param mute Boolean object indicating whether or not sound is needed.
* @returns Boolean true if range is buffered.
*/
		public function buffered(first:Number, last:Number, mute:Boolean, rebuffer:Boolean):Boolean
		{
			var is_buffered:Boolean = false;
			try
			{
				var media_range:Object = __mediaRange(first, last);
			// get module will attempt to create the module if it doesn't yet exist
				if (_module != null)
				{
					
					is_buffered = _module.buffered(media_range.start, media_range.end, mute || (! __hasA()), rebuffer);
				}
				var z:uint;
				var clip:IClipEffect;
				z = __effects.length;
				var i:uint;
				if (z)
				{
					for (i = 0; i < z; i++)
					{
						clip = __effects[i];
						if (! clip.buffered(media_range.start, media_range.end, mute || (! __hasA()), rebuffer))
						{
							is_buffered = false;
						}
					}
				}

			}
			catch(e:*)
			{
				RunClass.MovieMasher['msg'](this + '.buffered', e);
			}
			return is_buffered;
		}
/**
* Translates mash time to {@link Clip} time.
* 
* @param time Float object containing mash time
* @returns Float object containing {@link Clip} time
*/
		final public function clipTime(frame:Number):Number 
		{ 
			return __mediaFrame(frame - __startFrame);
		}
/**
* Gets a property's value.
* 
* @param property String containing property name
* @returns {@link Value} for named property
*/
		override public function getValue(property:String):Value
		{
			var value:Value = null;
			try
			{
				switch(property)
				{
					case 'readonly':
						value = new Value(__readOnly ? 1 : 0);
						break;
					case ClipProperty.TRACK:
						value = new Value(track);
						break;
					case 'kind':
						value = new Value('Clip');
						break;
					case ClipProperty.EFFECTS:
						value = new Value(__arrayEffects());
						break;
					case ClipProperty.COMPOSITES:
						value = new Value(__arrayComposites());
						break;
					case ClipProperty.XML:
						value = new Value(__xml());
						break;
					case ClipProperty.SPEED:
						if (__isModular()) value = super.getValue(property);
						else value = new Value(__speed);
						break;
					case CommonWords.TYPE:
						value = new Value(__type);
						break;
					case ClipProperty.LENGTHSECONDS:
						value = new Value(RunClass.TimeUtility['timeFromFrame'](lengthFrame, ((__mash == null) ? 0 : __mash.getValue(MashProperty.QUANTIZE).number)));
						break;
					case ClipProperty.LENGTH:
					case ClipProperty.LENGTHFRAME:
						value = new Value(lengthFrame);
						break;
					case ClipProperty.STARTFRAME:
					case ClipProperty.START:
						value = new Value(__startFrame);
						break;
					case ClipProperty.INDEX:
						value = new Value(__index);
						break;
					case ClipProperty.TRIMSTARTFRAME:
					case ClipProperty.TRIMENDFRAME:
					case ClipProperty.TRIMSTART:
					case ClipProperty.TRIMEND:
						value = new Value(__trimFrame(((property == ClipProperty.TRIMEND) || (property == ClipProperty.TRIMENDFRAME))));
						break;
					case ClipProperty.TRIM:
						value = __trimValue();
						break;
					case CommonWords.TYPE:
					case MediaProperty.WAVE:
					case MediaProperty.LOOP:
					case MediaProperty.WIDTH:
					case MediaProperty.HEIGHT:
					case MediaProperty.URL:
					case MediaProperty.ICON:
					case MediaProperty.NONEDITABLE:
					case MediaProperty.COMPOSITEEDITABLE:
					case MediaProperty.AUDIO:
					case 'swap':
						value = __media.getValue(property);
						break;
					case MediaProperty.DURATION: // number of frames in mash quantization of media as a float
						value = new Value(RunClass.TimeUtility['frameFromTime'](__mediaLength, ((__mash == null) ? 0 : __mash.getValue(MashProperty.QUANTIZE).number), ''));
						break;
					case ClipProperty.HASAUDIO:
						value = new Value(__hasA());
						break;
					case ClipProperty.ISAUDIO:
						value = new Value(__hasA(true));
						break;
					case ClipProperty.HASVISUAL:
						value = new Value(__type != ClipType.AUDIO);
						break;
					case ClipProperty.TIMELINESTARTFRAME:
						value = new Value(__timelineStartFrame());
						break;
					case ClipProperty.TIMELINEENDFRAME:
						value = new Value(__timelineEndFrame());
						break;
					case ClipType.MASH:
						value = new Value(__mash);
						break;
					case ClipProperty.VOLUME:
						if (! __hasA(true))
						{
							value = new Value();
							break;
						}
					default:
						if (__composites.length)
						{
							if (getValue(MediaProperty.COMPOSITEEDITABLE).array.indexOf(property) != -1)
							{
								value = __composites[0].getValue(property);
								//RunClass.MovieMasher['msg'](this + '.getValue ' + property + ' ' + __composites.length + ' ' + getValue(MediaProperty.COMPOSITEEDITABLE).string + ' ' + value);

							}
							
						}
						if (value == null) value = super.getValue(property);
				}	
			}
			catch(e:*)
			{
				RunClass.MovieMasher['msg'](this + '.getValue ' + property, e);
			}
			return value;
		}
		override public function toString():String
		{
			var s:String = '[Clip';
			var value:Value;
			value = getValue('label');
			if (! value.empty)
			{
				s += ' ' + value.string;
			}
			else if (__media != null)
			{
				value = __media.getValue(MediaProperty.LABEL);
				if (value.empty)
				{
					value = __media.getValue(CommonWords.ID);
				}
				if (! value.empty)
				{
					s += ' ' + value.string;
				}
			}
			s += ']';
			return s;
		}
/**
* Copies clip by instancing from tag.
* 
* @returns IClip copy of target
*/
		public function clone():IClip 
		{ 
			return fromXML(__xml(), __mash, __media); 
		}
/**
* Returns properties that can be bound to controls.
* 
* @returns Array of Strings containing property names
*/
		public function editableProperties():Array
		{
			var a:Array = null;
			if (! __readOnly)
			{				
				var nons:Array = getValue(MediaProperty.NONEDITABLE).array;
				a = new Array();
				for (var property:String in _defaults)
				{
					if (nons.indexOf(property) == -1)
					{
						if (propertyDefined(property))
						{
							a.push(property);
						}
					}
				}
			}
			return a;
		}
/**
* Whether or not the clip should appear on the visual track.
* 
* @returns Boolean true if clip is {@link Video}, {@link Image} or {@link Transition} 
*/
		public function isVisual():Boolean
		{
			return ( ! ((__type == ClipType.AUDIO) || (__type == ClipType.EFFECT)));
		}
		
/**
* Tests for existence of named property.
* 
* @param property String containing property name.
* @returns Boolean true if property is defined.
*/
		public function propertyDefined(property:String):Boolean
		{
			var defined:Boolean = false;
			var nons:Array = getValue(MediaProperty.NONEDITABLE).array;
			if (nons.indexOf(property) == -1)
			{
				switch(property)
				{
					case ClipProperty.TRACK:
						break;
					case CommonWords.TYPE:
						defined = true;
						break;
					case ClipProperty.VOLUME:
						defined = __hasA(true);
						break;
					case ClipProperty.LENGTH:
						if (track < 0) break;
					//case ClipProperty.EFFECTS:
					default:
						defined = (_defaults[property] != null);
				}
			}
			return defined;
		}
/**
* Search for media and fonts used by clip.
*
* Will put copy of object's XML tag for each referenced media item and font at key with its ID.
*
* @param object Object to add keys to.
*/
		public function referencedMedia(object:Object):void
		{
			var media_id:String = 'K' + RunClass.MD5['hash'](__media.getValue(CommonWords.ID).string);
			var xml_tag:XML;
			var list:XMLList;
			var child:XML;
			if (object[media_id] == null)
			{
				xml_tag = __media.tag.copy();
				list = xml_tag.media;
				if (list.length())
				{
					// flatten nested media tags
					for each (child in list)
					{
						object['K' + RunClass.MD5['hash'](child.@[CommonWords.ID])] = child;
					}
					delete xml_tag.media;
				}
				object[media_id] = xml_tag;
			}
			
			
			if (__isModular())
			{
				var values:Object = XMLUtility.attributeData(_tag);
				for (var k:String in values)
				{
					if (k.substr(0, 4) == ModuleProperty.FONT)
					{
						if (values[k].length)
						{
							media_id = 'K' + RunClass.MD5['hash'](values[k]);
							if (object[media_id] == null)
							{
								xml_tag = RunClass.MovieMasher['searchTag'](TagType.OPTION, values[k], CommonWords.ID);
								
								if (xml_tag != null)
								{
									object[media_id] = xml_tag.copy();
									
								}
							}
						}
					}
				}
			}
				
			var clip:IClip;
			var z:uint;
			var i:uint;
			z = __effects.length;
			if (z)
			{
				for (i = 0; i < z; i++)
				{
					clip = __effects[i];
					clip.referencedMedia(object);
				}
			}
			z = __composites.length;
			if (z)
			{
				for (i = 0; i < z; i++)
				{
					clip = __composites[i];
					clip.referencedMedia(object);
				}
			}


		}
/**
* Passes frame to module, after converting with clipTime method. 
* @param frame Number in mash's timescale. 
* @returns Boolean true if this call made a visual change from the last call. 
*/
		public function setFrame(frame:Number):void
		{
			try
			{
				var clip_time:Number = clipTime(frame);
				var backcolor:String;
				var display:DisplayObjectContainer = null;
				display = displayObject;
				__maskedSprite.removeContent();
				if (_module != null)
				{
					_module.setFrame(clip_time);
						
					if (_module.displayObject != null) 
					{
						__maskedSprite.addDisplay(_module.displayObject);
					}
					if (__type == ClipType.THEME) 
					{
						if (! track) 
						{
							backcolor = _module.backColor;
						}
						__maskedSprite.background = backcolor;
					}
				}
				__maskedSprite.applyEffects(__effects, clip_time);
				
			}
			catch(e:*)
			{
				RunClass.MovieMasher['msg'](this + '.setFrame ' + __maskedSprite, e);
			}
		}
		override public function setValue(value:Value,property:String):Boolean
		{
			var length_changed:Boolean = false; // if true we'll adjust our lengths
			try
			{
						
				switch (property)
				{
					case ClipProperty.SPEED:
						if (__isModular()) break; // modules might use as properties
					case ClipProperty.LENGTH:
					case ClipProperty.START:
					case ClipProperty.TRIM:
					case ClipProperty.TRIMSTART:
					case ClipProperty.TRIMEND:
					case ClipProperty.TRIMSTARTFRAME:
					case ClipProperty.TRIMENDFRAME:
					case ClipProperty.LOOPS:
					
						length_changed = (track >= 0);
						break;
					
				}
				var dirty_mash:Boolean = (__mash != null); // if true, we'll set mash's dirty property (unneeded for properties that affect mash length )
				var do_super:Boolean = true; // if true, we'll call super.setValue
				var set_this:Boolean = false; // if true, we'll set this[property] to value.number
				var dispatch:Boolean = true;
				switch(property)
				{
					case 'mute':
						property = MediaProperty.AUDIO;
						value = new Value(value.boolean ? 0 : 1);
						dirty_mash = false;
						dispatch = false;
						break;
					case ClipProperty.EFFECTS:
						__setEffects(value.array);
						do_super = false;
						break;
					case ClipProperty.COMPOSITES:
						__setComposites(value.array);
						do_super = false;
						break;
					case ClipProperty.SPEED:
						if (! __isModular())
						{
							var dif:Number = __speed / value.number;
							__endTrimFrame = Math.round(__endTrimFrame * dif);
							__startTrimFrame = Math.round(__startTrimFrame * dif);
							__speed = value.number;
							__calculateLength();
							dirty_mash = (track < 0);
						}
						break;
					case ClipType.MASH:
						__mash = (value.undefined ? null : value.object as IMash);
						length_changed = true;
						do_super = false;
						dirty_mash = false;
						dispatch = false;
						break;
					
					case ClipProperty.START:
						//do_super = ! isVisual();
						dirty_mash = false;
						__startFrame = value.number;
						break;
					case ClipProperty.TRACK:
						dirty_mash = false;
						set_this = true;
						break;
					case ClipProperty.LENGTHSECONDS:
						if ((__type == ClipType.IMAGE) || __isModular())
						{
							if (value.boolean)
							{
								lengthFrame = Math.round(RunClass.TimeUtility['frameFromTime'](value.number, ((__mash == null) ? 0 : __mash.getValue(MashProperty.QUANTIZE).number))); // collision detection for effects
								value = getValue(ClipProperty.LENGTHSECONDS);
								length_changed = true;
							}
						}
						do_super = false;
						dirty_mash = false;
						break;
						
					case ClipProperty.LENGTHFRAME:
						dispatch = false; // low level access to set length without dirtying mash
					case ClipProperty.LENGTH:
						if ((__type == ClipType.IMAGE) || __isModular())
						{
							if (value.boolean)
							{
								lengthFrame = Math.round(value.number); // collision detection for effects
								property = ClipProperty.LENGTH;
								value = getValue(ClipProperty.LENGTH);
								length_changed = true;
							}
						}
						do_super = false;
						dirty_mash = false;
						break;
					case ClipProperty.TRIMSTART:
					case ClipProperty.TRIMSTARTFRAME:
						dirty_mash = (track < 0);
						do_super = false;
						__setTrimStart(value.number, (__type != ClipType.AUDIO));
						break;
					case ClipProperty.TRIMEND:
					case ClipProperty.TRIMENDFRAME:
						dirty_mash = (track < 0);
						do_super = false;
						__setTrimEnd(value.number, (__type != ClipType.AUDIO));
						break;
					case ClipProperty.TRIM:
						dirty_mash = (track < 0);
						do_super = false;
						__setTrim(value, (__type != ClipType.AUDIO)); // collision detection for audio
						break;
					case ClipProperty.LOOPS:
						__setLoops(value);
						dirty_mash = false;
						do_super = false;
						break;
					default:
						if (__composites.length)
						{
							if (getValue(MediaProperty.COMPOSITEEDITABLE).array.indexOf(property) != -1)
							{
								length_changed = __composites[0].setValue(value, property);
								do_super = false;
							}
						}
					
				}
				if (set_this)
				{
					this[property] = value.number;
				}
				if (do_super)
				{
					super.setValue(value,property);
				}
				if (dirty_mash)
				{
					__mash.setValue(new Value(1), PlayerProperty.DIRTY);
				}
				if (length_changed)
				{
					__adjustLengthEffects();
					__adjustLengthComposites();
				}
				if (dispatch)
				{
					dispatchEvent(new ChangeEvent(value, property));
					dispatchEvent(new Event(Event.CHANGE));
				}
			}
			catch(e:*)
			{
				RunClass.MovieMasher['msg'](this + '.setValue ' + property + ' '+ value, e);
			}
			return length_changed;
		}
/**
* Marks some assets for eventual unloading
* 
* @param first int describing start time to buffer
* @param last int describing end time to buffer
*/
		public function unbuffer(first:Number = -1, last:Number = -1):void
		{
			try
			{
				var range:Object = __mediaRange(first, last);
				if (_module != null)
				{
					
					_module.unbuffer(range.start, range.end);
				}
									
				var z:uint = __effects.length;
				if (z)
				{
					var clip:IClip;
					for (var i:uint = 0; i < z; i++)
					{
						clip = __effects[i];
						clip.unbuffer(range.start, range.end);
					}
				}

			}
			catch(e:*)
			{
				RunClass.MovieMasher['msg'](this + '.unbuffer', e);
			}
		}
/**
* Marks all assets for unloading
* 
*/
		public function unload():void
		{
			try
			{
				__destroyDisplayObject();
				if (_module != null)
				{
					_module.removeEventListener(EventType.BUFFER, _moduleBuffer);
					_module.removeEventListener(EventType.STALL, _moduleStall);
					_module.unload();
					_module = null;
				}
				__requestedModule = false;

				var clip:IClip;
				var i:uint;
				var z:uint;
				z = __effects.length;
				for (i = 0; i < z; i++)
				{
					clip = __effects[i];
					/* DON'T stop listening
					clip.removeEventListener(EventType.BUFFER, __clipBuffer);
					clip.removeEventListener(EventType.STALL, __clipStall);
					*/
					clip.unload();
				}
			
			}
			catch(e:*)
			{
				RunClass.MovieMasher['msg'](this, e);
			}
		}
/**
* Calculates clip volume for a given time and global volume level.
* 
* @param project_time Float containing mash time intersecting with clip
* @param percent Float containing global volume level, zero to a hundred
* @returns Float containing volume level, zero to one
* @see Mash
*/
		public function volumeFromTime(project_time:Number, percent:Number):Number
		{
			var n:Number = percent;
			if (percent)
			{
				var value:Value = getValue(ClipProperty.VOLUME);
				if (! value.empty)
				{
					var plot:Array = RunClass.PlotUtility['string2Plot'](value.string);
					
					n = RunClass.PlotUtility['value'](plot, ((project_time - __startFrame) * 100) / __lengthFrame);
					
					n = (percent * n) / 100;
				}
				n = n / 100;
			}
			return n;
		}	
		public function get audioIsPlayable():Boolean
		{
			var tf:Boolean = __media.audioIsPlayable;
			if ((! tf) && __isModular())
			{
				var z:uint = __composites.length;
				for (var i:uint = 0; i < z; i++)
				{
					if (__composites[i].audioIsPlayable)
					{
						tf = true;
						break;
					}
				}
			}
			return tf;
		}
		
		public function get audioIsExtractable():Boolean
		{
			return __media.audioIsExtractable;
		}
		public function get backColor():String
		{
			var string:String = getValue(ModuleProperty.BACKCOLOR).string;
			if ((! string.length) && (_module != null))
			{
				string = _module.backColor;
			}
			return string;
		}
		public function get canTrim():Boolean
		{
			var can:Boolean = false;
			switch (__type)
			{
				case ClipType.AUDIO:
					can = ! __mediaDoesLoop;
					break;
				case ClipType.VIDEO:
					can = true;
					break;
			}
			return can;
		}
		
		public function get displayObject():DisplayObjectContainer
		{
			
			if (__maskedSprite == null) __createDisplayObject();
			return __maskedSprite;
		}
		
		public function get endPadFrame():Number
		{ 
			return __endPadFrame; 
		}
		public function set endPadFrame(value:Number):void
		{ 
			if (__endPadFrame != value) __endPadFrame = value; 
		}
	
		public function get index():int
		{ 
			return __index; 
		}
		public function set index(value:int):void
		{ 
			if (__index != value) __index = value; 
		}
		public function get keepsTime():Boolean
		{
			var keeps:Boolean = false;
			if (_module != null)
			{
				keeps = _module.keepsTime;
			}
			return keeps;
		}
		public function getFrame():Number
		{
			var n:Number = -1;
			if (_module != null)
			{
				n = _module.getFrame();
			}
			if (n != -1)
			{
				var trim_start:Number = __trimFrame();
				if ((n > (startPadFrame + trim_start + __lengthFrame)) || (n < trim_start))
				{
					n = -1;
				}
				else
				{
					switch(__type)
					{
						case ClipType.AUDIO:
						case ClipType.VIDEO:
							n = (n - (__trimFrame() + startPadFrame)) + __startFrame;
							break;
						default:
							n = n + __startFrame;
					}
				}
			}
			return n;
		}
		public function get lengthFrame():Number
		{ 
			var lf:Number = __lengthFrame;
			try
			{
				if (lf == 0)
				{
					var quantize:int = 0;
					
					var mash_null:Boolean = (__mash == null);
					if (! mash_null) quantize = __mash.getValue(MashProperty.QUANTIZE).number;
	
					lf = __mediaLength;
					if (__speed != 1) lf *= __speed;
					
					lf = RunClass.TimeUtility['convertFrame'](lf, 1, quantize, 'floor');
					if (__endTrimFrame || __startTrimFrame)
					{
						lf -= __endTrimFrame + __startTrimFrame;
					}
					if (! mash_null) __lengthFrame = lf;
				}
			}
			catch(e:*)
			{
				RunClass.MovieMasher['msg'](this + '.lengthFrame', e);
			}
			return lf; 
		}
		
		public function set lengthFrame(n:Number):void
		{ 
			var number:Number = n;
			if (__mash != null)
			{
				if (__type == ClipType.EFFECT) // check for collision in this effects track
				{
					var tracks:Array = __mash.clipsInOuterTracks(__startFrame, __startFrame + n, [this], track, 1, ClipType.EFFECT);
					var z:int = tracks.length;
					if (z)// hit something
					{
						var clip:IClip = tracks[0];
						//RunClass.MovieMasher['msg'](this + '.lengthFrame hit ' + clip);
						n = clip.startFrame - __startFrame;
					}
				}
			}
			
			// enforce minimum clip length
			var minlength:Number = RunClass.MovieMasher['getOptionNumber']('clip', 'minlength');
			if (! minlength) minlength = 1;
			if (n < minlength) n = minlength;
			
			__lengthFrame = Math.round(n);
		}
		public function get media():IMedia
		{	
			return __media; 
		}
		public function get mash():IMash
		{	
			return __mash; 
		}
		public function get metrics():Size
		{
			return __metrics;
		}
		public function set metrics(iMetrics:Size):void
		{
			try
			{
				__metrics = iMetrics;
				if (_module != null)
				{
					_module.metrics = __metrics;
				}
				if (__maskedSprite != null)
				{
					__maskedSprite.metrics = __metrics;
				}
			}
			catch(e:*)
			{
				RunClass.MovieMasher['msg'](this + '.metrics', e);
			}
		}
/**
* The {@link IModule} instance associated with this clip.
* 
* @see AVAudio
* @see AVImage
* @see AVMash
* @see AVSequence
* @see AVVideo
*/
		public function get module():IModule
		{
			if (_module == null) __requestModule();
			return _module;
		}
/**
* Boolean indicating whether or not the clip should be trying to play.
*/
		public function set playing(iBoolean:Boolean):void
		{
			
			if (__playing != iBoolean)
			{
				__playing = iBoolean;
				if (_module != null) 
				{
					_module.playing = __playing;
				}
				var z:uint;
				var clip:IClip;
				z = __effects.length;
				var i:uint;
				if (z)
				{
					for (i = 0; i < z; i++)
					{
						clip = __effects[i];
						clip.playing = __playing;
					}
				}
			}
		}
		public function get startFrame():Number
		{ 
			return __startFrame; 
		}
		public function set startFrame(value:Number):void
		{ 
			if (__startFrame != value) __startFrame = value; 
		}
		public function get startPadFrame():Number
		{ 
			return __startPadFrame; 
		}
		public function set startPadFrame(value:Number):void
		{ 
			if (__startPadFrame != value) __startPadFrame = value; 
		}
		public function get track():int
		{	 
			return __track;	
		}
		public function set track(value:int):void
		{	
			__track = value;	
		}
		public function set volumeLevel(value:Number):void
		{	
			if (_module != null)
			{
				_module.volumeLevel = value;
			}
			var z:uint;
			var clip:IClip;
			z = __effects.length;
			var i:uint;
			if (z)
			{
				for (i = 0; i < z; i++)
				{
					clip = __effects[i];
					clip.volumeLevel = value;
				}
			}
		}
		public function get type():String
		{	
			return __type;	
		}
		override protected function _parseTag():void
		{
			try
			{
				var clip_length:Number = super.getValue(ClipProperty.LENGTH).number;
				var value:Value = null;
				_defaults[ClipProperty.TRACK] = '0';
				
				if (__type != ClipType.AUDIO) _defaults[ClipProperty.EFFECTS] = '';
				if (__media != null)
				{
					value = __media.getValue(MediaProperty.LABEL);
					if (value.empty)
					{
						value = __media.getValue(CommonWords.ID);
					}
					if (! value.empty)
					{
						_defaults[MediaProperty.LABEL]  = value.string;
					}
				}
				switch (__type)
				{
					case ClipType.AUDIO:
						__mediaDoesLoop = __media.getValue(MediaProperty.LOOP).boolean;
					case ClipType.VIDEO:
					case ClipType.MASH:
						_defaults[MediaProperty.AUDIO] = '1';
						break;
				}
				__mediaLength = __media.seconds;
				//if (! __mediaLength) RunClass.MovieMasher['msg'](this + '._parseTag could not determine media length');
				switch (__type)
				{
					case ClipType.EFFECT:
						_defaults[ClipProperty.LENGTH] = '0';
						_defaults[ClipProperty.LENGTHSECONDS] = '0';
						_defaults[ClipProperty.START] = '0';
						
						break;
					case ClipType.IMAGE:
						_defaults[MediaProperty.FILL] = __media.getValue(MediaProperty.FILL).string;
					case ClipType.THEME:
						_defaults[ClipProperty.LENGTH] = '0';
						_defaults[ClipProperty.LENGTHSECONDS] = '0';
						break;
					case ClipType.TRANSITION:
						_defaults[ClipProperty.LENGTH] = '0';
						_defaults[ClipProperty.LENGTHSECONDS] = '0';
						_defaults[ClipProperty.FREEZESTART] = '0';
						_defaults[ClipProperty.FREEZEEND] = '0';
						break;
					case ClipType.VIDEO:
						_defaults[MediaProperty.FILL] = __media.getValue(MediaProperty.FILL).string;
						_defaults[ClipProperty.TRIM] = '';
						var url:String = __media.getValue(MediaProperty.URL).string;
						if (__canSpeed(url))
						{
							_defaults[ClipProperty.SPEED] = '1';
						}
						url = __media.getValue(ClipType.AUDIO).string;
						if (url.length)
						{
							_defaults[ClipProperty.VOLUME] = Fades.SEVENTY;
						}
						break;
					case ClipType.AUDIO:
						_defaults[ClipProperty.START] = '0';
						_defaults[ClipProperty.VOLUME] = Fades.SEVENTY;
						if (__mediaDoesLoop) _defaults[ClipProperty.LOOPS] = '1';
						else 
						{
							_defaults[ClipProperty.TRIM] = '';
						}
						break;
					case ClipType.MASH:
						_defaults[ClipProperty.TRIM] = '';
						_defaults[ClipProperty.VOLUME] = Fades.SEVENTY;
						break;
				}
				var k:String;
				// make sure there are default values for all of media's editable attributes
				var props:Object = __media.clipProperties();
				__readOnly = (props == null);
				
				if (! __readOnly) // if it is, then 'editable' attribute is probably blank
				{
					for (k in props)
					{
						_defaults[k] = props[k];
					}
				}
				// initialize runtime variables, some things sort by track
				__track = super.getValue(ClipProperty.TRACK).number;
				if (_defaults[ClipProperty.START] != null)
				{
					__startFrame = parseFloat(super.getValue(ClipProperty.START).string);
				}
				if (_defaults[ClipProperty.SPEED] != null) 
				{
					if (! __isModular())
					{
						__speed = parseFloat(super.getValue(ClipProperty.SPEED).string);
					}
				}
				if (_defaults[ClipProperty.LENGTH] != null) // true for transitions, effects, themes, images
				{
					__lengthFrame = super.getValue(ClipProperty.LENGTH).number;
				}
				else if (_defaults[ClipProperty.TRIM] != null) // video and non looping audio
				{	
					_defaults[ClipProperty.TRIMSTART] = '0';
					_defaults[ClipProperty.TRIMEND] = '0';
					var trimstart:Number = super.getValue(ClipProperty.TRIMSTART).number;
					var trimend:Number = super.getValue(ClipProperty.TRIMEND).number;
					__startTrimFrame = trimstart;
					__endTrimFrame = trimend;
					__calculateLength();//clip_length);
				}
				else // it is a looping audio clip
				{
					__setLoops(getValue(ClipProperty.LOOPS), true); // doesn't check for collision
				}
				
				// look for effect and composite clips embedded in me
				var children:XMLList = _tag.clip;
				var clip : IClip;
				if (children.length())
				{
					for each (var clip_node : XML in children)
					{
						clip = fromXML(clip_node, __mash);
						if (String(clip_node.@type) == ClipType.EFFECT)
						{
							if (clip is IClipEffect)
							{
								__effects.push(clip as IClipEffect);
								clip.addEventListener(EventType.BUFFER, _moduleBuffer);
								clip.addEventListener(EventType.STALL, _moduleStall);
							}
							else RunClass.MovieMasher['msg'](this + '._parseTag effect is not IClipEffect ' + clip);
						}
						else
						{
							__composites.push(clip);
						}
					}
					try
					{
						__adjustLengthEffects();
						__adjustLengthComposites();
					}
					catch(e:*)
					{
						RunClass.MovieMasher['msg'](this + '._parseTag __adjustLengths', e);
					}
				}
				else
				{
					var composites:String = super.getValue(ClipProperty.COMPOSITES).string;
					if (composites.length)
					{
						var a:Array = composites.split(',');
						for each (composites in a)
						{
							clip = Clip.fromMediaID(composites, null, __mash);
							if (clip != null) __composites.push(clip);
						}
						__adjustLengthComposites();
					}
				}
			}
			catch(e:*)
			{
				RunClass.MovieMasher['msg'](this + '._parseTag', e);
			}
		}
		private function __adjustLengthComposites():void
		{
			var z:uint = __composites.length;
			if (z)
			{
				var clip:IClip;
				var value:Value = getValue(ClipProperty.LENGTHFRAME);
				var mash_value:Value = new Value(__mash);
				for (var i:uint = 0; i < z; i++)
				{
					clip = __composites[i];
					clip.setValue(value, ClipProperty.LENGTHFRAME);
					clip.setValue(mash_value, ClipProperty.MASH);
					clip.setValue(new Value(1), 'mute');
					clip.track = i - z;
					
				}
			}
		}
		private function __adjustLengthEffects():void
		{
			var z:uint = __effects.length;
			if (z)
			{
				var clip:IClipEffect;
				var value:Value = getValue(ClipProperty.LENGTHFRAME);
				var mash_value:Value = new Value(__mash);
				for (var i:uint = 0; i < z; i++)
				{
					clip = __effects[i];
					clip.setValue(value, ClipProperty.LENGTHFRAME);
					clip.setValue(mash_value, ClipProperty.MASH);
					clip.track = i - z;
				}
			}
		}
		private function __arrayComposites():Array
		{
			var array:Array = new Array();
			var i,z:int;
			z = __composites.length;
			for (i = 0; i < z; i++)
			{
				array.push(__composites[i]);
			}
			return array;
		}
		private function __arrayEffects():Array
		{
			var array:Array = new Array();
			var i,z:int;
			z = __effects.length;
			for (i = 0; i < z; i++)
			{
				array.push(__effects[i]);
			}
			return array;
		}
		
		private function __canSpeed(url:String):Boolean
		{
			return (url.substr(-1) == '/');
		}
		private function __calculateLength():void
		{
			__lengthFrame = 0;
			__adjustLengthEffects();
			__adjustLengthComposites();
			/*
			var quantize:Number = 0;
			if (mash != null)
			{
				quantize = mash.getValue(MashProperty.QUANTIZE).number;
			}
			if (frames <= 0) frames = (RunClass.TimeUtility['frameFromTime'](__mediaLength, quantize) * __speed) - (__endTrimFrame + __startTrimFrame);
			
			if (lengthFrame != frames)
			{
				__lengthFrame = frames;
			}
			*/
		}
		private function __createModule(loader:IAssetFetcher, url:String):void
		{
			try
			{
				var c:Class = loader.classObject(url, 'module');
				if (c != null)
				{
					_module = new c() as IModule;
					if (_module != null)
					{
						try
						{
							_module.clip = this;
							_module.addEventListener(EventType.BUFFER, _moduleBuffer);
							_module.addEventListener(EventType.STALL, _moduleStall);
							
							dispatchEvent(new Event(EventType.BUFFER));
						}
						catch(e:*)
						{
							RunClass.MovieMasher['msg'](this + '.__createModule', e);
						}
					}
					else RunClass.MovieMasher['msg'](this +  '.__createModule unable to instance ' + c);
				}
			}
			catch(e:*)
			{
				RunClass.MovieMasher['msg'](this + '.__createModule', e);
			}
		}
		private function __createDisplayObject():void
		{
			__maskedSprite = new MaskedSprite();
			__maskedSprite.name = 'CLIP CANVAS';
			if (__metrics != null)
			{
				__maskedSprite.metrics = __metrics;
			}
		}
		private function __destroyDisplayObject():void
		{
			if (__maskedSprite != null) 
			{	
				
				__maskedSprite.unload();
				__maskedSprite = null;
			}
		}
		private function __hasA(ignore_enabled:Boolean = false):Boolean 
		{ 
			var tf:Boolean = false;
			var z:uint;
			var i:uint;
			switch(__type)
			{
				case ClipType.THEME:
				case ClipType.TRANSITION:
				case ClipType.EFFECT:
					z = __composites.length;
					for (i = 0; ((! tf) && (i < z)); i++)
					{
						tf = (__composites[i].getValue((ignore_enabled ? ClipProperty.ISAUDIO : ClipProperty.HASAUDIO)).boolean)
					}
					break;
				case ClipType.AUDIO:
				case ClipType.MASH:
					tf = (ignore_enabled || __volumeEnabled());
					break;
				case ClipType.VIDEO:
					//|| __media.audioIsExtractable
					//RunClass.MovieMasher['msg'](this + ".__hasA \n__media.audioIsPlayable = " + __media.audioIsPlayable + "\n__speed = " + __speed + "\ngetValue(MediaProperty.AUDIO).boolean = " + getValue(MediaProperty.AUDIO).boolean + "\nignore_enabled || __volumeEnabled() = " + (ignore_enabled || __volumeEnabled()));
					tf = __media.audioIsPlayable && ((__speed == 1) && (! getValue(MediaProperty.AUDIO).empty) && (ignore_enabled || __volumeEnabled()));
					break;
			}
			z = __effects.length;
			for (i = 0; ((! tf) && (i < z)); i++)
			{
				tf = (__effects[i].getValue((ignore_enabled ? ClipProperty.ISAUDIO : ClipProperty.HASAUDIO)).boolean)
			}
			//RunClass.MovieMasher['msg'](this + '.__hasA ' + tf);
			return tf; 
		}
		private function __mediaRange(first:Number, last:Number):Object
		{
			var media_range:Object = null;
			if (first != -1)
			{
				media_range = new Object();
				media_range.start = clipTime(first);
				media_range.end = clipTime(last);
			}
			return media_range;
		}
		private function __mediaFrame(project_time:Number):Number
		{
			var media_time:Number = project_time;
			try
			{
				switch (__type)
				{
					case ClipType.VIDEO:
						media_time = (project_time / __speed) + __trimFrame() + __startPadFrame;
						break;
					case ClipType.AUDIO:
						media_time = project_time + __trimFrame();
						break;
				}
			}
			catch(e:*)
			{
				RunClass.MovieMasher['msg'](this + '.__mediaTime', e);
			}
			
			return media_time;
		}
		private function _moduleBuffer(event:Event):void 
		{
			try
			{
				//RunClass.MovieMasher['msg'](this + '._moduleBuffer BUFFER ' + _module);
				
				if (_module != null)
				{
					dispatchEvent(new Event(EventType.BUFFER));
				}
			}
			catch(e:*)
			{
				RunClass.MovieMasher['msg'](this, e);
			}
		}
		private function _moduleStall(event:Event):void // called from embedded effects
		{ 
			try
			{
				if (_module != null)
				{
					dispatchEvent(new Event(EventType.STALL));
				}
			}
			catch(e:*)
			{
				RunClass.MovieMasher['msg'](this, e);
			}
		}
		private function __clipBuffer(event:Event):void  // called from embedded effects
		{
			try
			{
				//RunClass.MovieMasher['msg'](this + '.__clipBuffer effects BUFFER');
				dispatchEvent(new Event(EventType.BUFFER));
			}
			catch(e:*)
			{
				RunClass.MovieMasher['msg'](this, e);
			}
		}
		private function __clipStall(event:Event):void 
		{
			try
			{
				dispatchEvent(new Event(EventType.STALL));
			}
			catch(e:*)
			{
				RunClass.MovieMasher['msg'](this, e);
			}
		}
		
		private function __isModular():Boolean
		{
			var is_modular:Boolean = true;
			switch (__type)
			{
				case ClipType.AUDIO:
				case ClipType.IMAGE:
				case ClipType.VIDEO: 
					is_modular = false;	
					break;
			}
			return is_modular;
		}

		private function _moduleLoaded(event:Event):void
		{
			try
			{
				if (_module == null)
				{
					__createModule(event.target as IAssetFetcher, __symbolURL());
					
				}
			}
			catch(e:*)
			{
				RunClass.MovieMasher['msg'](this, e);
			}

		}
		private function __requestModule():void
		{
			try
			{
				if (! __requestedModule)
				{
					__requestedModule = true;
					
					
					var symbol:String = __symbolURL();
					
					if (symbol.length)
					{
						var loader:IAssetFetcher = RunClass.MovieMasher['assetFetcher'](symbol, 'swf');
						
						if (loader.state == EventType.LOADED)
						{
							__createModule(loader, symbol);
						}
						else 
						{
							loader.addEventListener(Event.COMPLETE, _moduleLoaded);
						}
					}
				}
			}
			catch(e:*)
			{
				RunClass.MovieMasher['msg'](this, e);
			}
		}
		private function __setEffects(effects:Array):void
		{
			__unloadEffects(effects);
			var i,z:uint;
			z = effects.length;
			var orig_effects:Vector.<IClipEffect> = __effects;
			__effects = new Vector.<IClipEffect>();
			for (i = 0; i < z; i++)
			{
				if (orig_effects.indexOf(effects[i]) == -1)
				{
					effects[i].setValue(new Value(__mash), ClipProperty.MASH);
					effects[i].addEventListener(EventType.BUFFER, __clipBuffer);
					effects[i].addEventListener(EventType.STALL, __clipStall);
					
				}
				__effects.push(effects[i]);
			}
			__adjustLengthEffects();
		}
		private function __setComposites(composites:Array):void
		{
			__unloadComposites(composites);
			var clip:IClip;
			var orig_composites:Vector.<IClip> = __composites;
			__composites = new Vector.<IClip>();
			
			var i,z:uint;
			z = composites.length;
			for (i = 0; i < z; i++)
			{
				clip = composites[i];
				if (orig_composites.indexOf(clip) == -1)
				{
					clip.setValue(new Value(__mash), ClipType.MASH);
				}
				__composites.push(clip);
			}
			__adjustLengthComposites();
		}
		private function __setLoops(value:Value, no_collision = false):void
		{
			value.number = Math.round(value.number);
			if (! no_collision)
			{
				var tracks:Array = __mash.clipsInOuterTracks(__startFrame, __startFrame + RunClass.TimeUtility['frameFromTime'](__mediaLength * value.number, mash.getValue(MashProperty.QUANTIZE).number), [this], track, 1, ClipType.AUDIO);
				if (tracks.length)
				{
					// hit something
					value.number = Math.floor((tracks[0].startFrame - __startFrame) / RunClass.TimeUtility['frameFromTime'](__mediaLength, mash.getValue(MashProperty.QUANTIZE).number));
				}
			}
			__lengthFrame = RunClass.TimeUtility['frameFromTime'](value.number * __mediaLength, mash.getValue(MashProperty.QUANTIZE).number);
			super.setValue(value, ClipProperty.LOOPS);
		}
		private function __setTrimStart(seconds:Number, no_collision:Boolean = false):void
		{
			try
			{
				var origtrim:Number = seconds;
				seconds = Math.max(seconds, 0);
				var other_trim:Number = getValue(ClipProperty.TRIMENDFRAME).number;
				var prev_trim:Number = getValue(ClipProperty.TRIMSTARTFRAME).number;
				var dif:Number = prev_trim - seconds;
				
				if (dif)
				{
					
					if (dif < 0) // making clip smaller
					{
						// enforce minimum clip length
						var minlength:Number = RunClass.MovieMasher['getOptionNumber']('clip', 'minlength');
						if (minlength) minlength = RunClass.TimeUtility['frameFromTime'](minlength, mash.getValue(MashProperty.QUANTIZE).number);
						else minlength = 1;
						
						seconds = Math.min(seconds, RunClass.TimeUtility['frameFromTime'](__mediaLength * __speed, mash.getValue(MashProperty.QUANTIZE).number) - (other_trim + minlength));
					}
					else // making clip bigger
					{
						if (! no_collision)
						{
							// make sure we don't collide with something to left
							var tracks:Array = __mash.clipsInOuterTracks(__startFrame - dif, __startFrame, [this], track, 1, ClipType.AUDIO);
							
							if (tracks.length)
							{
								// hit something
								var clip:Clip = tracks[tracks.length - 1];
								seconds = (RunClass.TimeUtility['frameFromTime'](__mediaLength * __speed, mash.getValue(MashProperty.QUANTIZE).number) - other_trim) - RunClass.TimeUtility['timeFromFrame'](__startFrame + __lengthFrame - (clip.startFrame + clip.lengthFrame), mash.getValue(MashProperty.QUANTIZE).number);
							}
						}
					}
					dif = seconds;
					if (track >= 0)
					{
						__startFrame += dif - __startTrimFrame;
						setValue(new Value(__startFrame), ClipProperty.START); // so tag is updated too
					}
					//if (origtrim != dif) RunClass.MovieMasher['msg'](this + '.__setTrimStart ' + origtrim + '->' + dif);
					__startTrimFrame = dif;
					
					__calculateLength();
					var value:Value = new Value(seconds);
					super.setValue(value, ClipProperty.TRIMSTART);
					dispatchEvent(new ChangeEvent(value, ClipProperty.TRIMSTART));
					dispatchEvent(new ChangeEvent(value, ClipProperty.TRIM));
				}
			}			
			catch(e:*)
			{
				RunClass.MovieMasher['msg'](this + '.__setTrimStart', e);
			}

		}
		private function __setTrimEnd(seconds:Number, no_collision:Boolean = false):void
		{
			try
			{
				seconds = Math.max(seconds, 0);
				var other_trim:Number = super.getValue(ClipProperty.TRIMSTART).number;
				var prev_trim:Number = super.getValue(ClipProperty.TRIMEND).number;
				var dif:Number = prev_trim - seconds;
				if (dif)
				{
					if (dif < 0) // making clip smaller
					{
						// enforce minimum clip length
						var minlength:Number = RunClass.MovieMasher['getOptionNumber']('clip', 'minlength');
						if (minlength) minlength = (1 / mash.getValue(MashProperty.QUANTIZE).number);
						else minlength = 1;
						seconds = Math.min(seconds, RunClass.TimeUtility['frameFromTime'](__mediaLength * __speed, mash.getValue(MashProperty.QUANTIZE).number) - (other_trim + minlength));
					}
					else // making clip bigger
					{
						if (! no_collision)
						{
							// make sure we don't collide with something to left
							var tracks:Array = __mash.clipsInOuterTracks(__startFrame + __lengthFrame, __startFrame + __lengthFrame + dif, [this], track, 1, ClipType.AUDIO);
							
							if (tracks.length)
							{
								// hit something
								var clip:Clip = tracks[0];
								seconds = (RunClass.TimeUtility['frameFromTime'](__mediaLength * __speed, mash.getValue(MashProperty.QUANTIZE).number) - other_trim) - (clip.startFrame - __startFrame);
							}
						}
					}
					dif = seconds;
					__endTrimFrame = dif;
					__calculateLength();					
					var value:Value = new Value(seconds);
					super.setValue(value, ClipProperty.TRIMEND);
					dispatchEvent(new ChangeEvent(value, ClipProperty.TRIMEND));
					dispatchEvent(new ChangeEvent(value, ClipProperty.TRIM));
				}
			}
			catch(e:*)
			{
				RunClass.MovieMasher['msg'](this + '.__setTrimEnd', e);
			}

		}
		private function __setTrim(value:Value, no_collision:Boolean = false):void
		{
			
			var value_array:Array = value.array;
			var old_trim:Array = getValue(ClipProperty.TRIM).array;
			old_trim[0] = parseFloat(old_trim[0]);
			old_trim[1] = parseFloat(old_trim[1]);
			value_array[0] = parseFloat(value_array[0]);
			value_array[1] = parseFloat(value_array[1]);
			
			
			if (Math.abs(value_array[0] - old_trim[0]) > Math.abs(value_array[1] - old_trim[1]))
			{
				__setTrimStart((RunClass.TimeUtility['frameFromTime'](__mediaLength * __speed * value_array[0] / 100, mash.getValue(MashProperty.QUANTIZE).number)), no_collision);
			}
			else 
			{
				__setTrimEnd((RunClass.TimeUtility['frameFromTime'](__mediaLength * __speed * value_array[1] / 100, mash.getValue(MashProperty.QUANTIZE).number)), no_collision);
			}
		}
		private function __symbolURL():String
		{
			
			var symbol:String = __media.getValue(MediaProperty.SYMBOL).string;
			if (symbol.length)
			{
				if (symbol.indexOf('@') == -1)
				{
					symbol = '@' + symbol;
				}
				if (symbol.indexOf('/') == -1)
				{
					symbol = __media.getValue(MediaProperty.URL).string + symbol;
				}
			}
			else
			{
				switch (__type)
				{
					case ClipType.MASH:
					case ClipType.AUDIO:
					case ClipType.IMAGE:
						symbol += '@AV' + __type.substr(0, 1).toUpperCase() + __type.substr(1);
						break;
					case ClipType.VIDEO:
						symbol += '@AV' + (__canSpeed(__media.getValue(MediaProperty.URL).string) ? 'Sequence':'Video');
						break;
				}
			}
			return symbol;
		}
		private function __timelineEndFrame():Number // returns time eaten up at end by transitions and padding
		{
			var trans_time:Number = 0;
			if (__mash)
			{
				switch (__type)
				{
					case ClipType.AUDIO:
					case ClipType.EFFECT:
					case ClipType.TRANSITION:
						break;
					default:
						if ((__index != -1) && (__index < (__mash.tracks.video.length - 1)))
						{
							if (__mash.tracks.video[__index + 1].getValue(CommonWords.TYPE).equals(ClipType.TRANSITION))
							{
								trans_time += __mash.tracks.video[__index + 1].lengthFrame;
						
								trans_time -= __endPadFrame;
							}
						}
				}
			}
			return trans_time;
		
		}
		private function __timelineStartFrame():Number // returns time eaten up at start by transitions and padding
		{
			var trans_time:Number = 0;
			if (__mash)
			{
				switch (__type)
				{
					case ClipType.AUDIO:
					case ClipType.EFFECT:
					case ClipType.TRANSITION:
						break;
					default:
						if (__index > 0)
						{
							if (__mash.tracks.video[__index - 1].getValue(CommonWords.TYPE).equals(ClipType.TRANSITION))
							{
								trans_time += __mash.tracks.video[__index - 1].lengthFrame;
								trans_time -= __startPadFrame;
							}
						}
				}
			}
			return trans_time;
		}
		private function __trimFrame(trim_end:Boolean = false):Number
		{
			var n:Number = 0;
			switch(__type)
			{
				case ClipType.EFFECT:
					break;
				case ClipType.AUDIO:
					if (__mediaDoesLoop) break;
				case ClipType.VIDEO:
					n = (trim_end ? __endTrimFrame : __startTrimFrame);
			}
			return n;
		}
		private function __trimValue():Value
		{
			var value:Value = new Value(0);
			if (__mash != null)
			{
				
				var media_frames:Number = RunClass.TimeUtility['frameFromTime'](__mediaLength, __mash.getValue(MashProperty.QUANTIZE).number) * __speed;
				value = new Value(((__startTrimFrame * 100) / media_frames) + ',' + ((__endTrimFrame * 100) / media_frames));
			}
			return value;
		}
		private function __unloadComposites(ignore:Array):void
		{
			
			var z:uint = __composites.length;
			for (var i:uint = 0; i < z; i++)
			{
				if (ignore.indexOf(__composites[i]) == -1)
				{
					__composites[i].setValue(new Value(), ClipProperty.MASH);
					if (type == ClipProperty.EFFECTS)
					{
						__composites[i].removeEventListener(EventType.BUFFER, _moduleBuffer);
						__composites[i].removeEventListener(EventType.STALL, _moduleStall);
					}
					__composites[i].unload();
				}
			}
		}
		private function __unloadEffects(ignore:Array):void
		{
			var z:uint = __effects.length;
			for (var i:uint = 0; i < z; i++)
			{
				if (ignore.indexOf(__effects[i]) == -1)
				{
					__effects[i].setValue(new Value(), ClipProperty.MASH);
					if (type == ClipProperty.EFFECTS)
					{
						__effects[i].removeEventListener(EventType.BUFFER, _moduleBuffer);
						__effects[i].removeEventListener(EventType.STALL, _moduleStall);
					}
					__effects[i].unload();
				}
			}
		}
		private function __volumeEnabled():Boolean
		{
			var tf:Boolean = (! super.getValue(ClipProperty.VOLUME).equals(Fades.OFF));
			return tf;
		}	
		private function __xml():XML
		{
			var result:XML = _tag.copy();
			__adjustLengthEffects();
			__adjustLengthComposites();
			
			
			delete result.clip; // composites and effects
			delete result.@composites;
			delete result.@effects;
			
			//result.setChildren(new XMLList());
			for (var k:String in _defaults)
			{
				switch (k)
				{
					case ClipProperty.EFFECTS:
					case ClipProperty.COMPOSITES:
					case ClipProperty.TRIM:
						break;
					default:
						result.@[k] = getValue(k).string;
				}
			}
			
			
			if ((__type == ClipType.VIDEO) || (__type == ClipType.AUDIO))
			{
				// because length is not in defaults
				result.@length = __lengthFrame;
			}
			var z:uint;
			var i:uint;
			var clip:IClip;
			z = __effects.length;
			if (z)
			{
				for (i = 0; i < z; i++)
				{
					clip = __effects[i];
					result.appendChild(clip.getValue(ClipProperty.XML).object as XML);
				}
			}
			z = __composites.length;
			if (z)
			{
				for (i = 0; i < z; i++)
				{
					clip = __composites[i];
					result.appendChild(clip.getValue(ClipProperty.XML).object as XML);
				}
			}
			return result;
		}
		

		private var __composites:Vector.<IClip>; 
		private var __effects:Vector.<IClipEffect>; 
		private var __endPadFrame:Number = 0;
		private var __endTrimFrame:Number = 0;
		private var __maskedSprite:MaskedSprite;

		private var __index:int = 0;
		private var __lengthFrame:Number = 0;
		private var __mash:IMash; // the mash object I'm inside of (might be null)
		private var __media:IMedia; // the media object that I am an instance of
		private var __mediaDoesLoop:Boolean;
		private var __mediaLength:Number = 0;
		protected var _module:IModule; // my visual representation in the player
		private var __mute:Boolean;
		private var __playing:Boolean;
		private var __requestedModule:Boolean = false;
		private var __speed:Number = 1;
		private var __startFrame:Number = 0;
		private var __startPadFrame:Number = 0;
		private var __startTrimFrame:Number = 0;
		private var __track:int = 0;
		private var __type:String;
		private var __readOnly:Boolean = false;
		private var __metrics:Size;
		
	}
}
