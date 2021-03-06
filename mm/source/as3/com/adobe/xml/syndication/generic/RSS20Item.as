/*
	Copyright (c) 2008, Adobe Systems Incorporated
	All rights reserved.

	Redistribution and use in source and binary forms, with or without 
	modification, are permitted provided that the following conditions are
	met:

    * Redistributions of source code must retain the above copyright notice, 
    	this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
		notice, this list of conditions and the following disclaimer in the 
    	documentation and/or other materials provided with the distribution.
    * Neither the name of Adobe Systems Incorporated nor the names of its 
    	contributors may be used to endorse or promote products derived from 
    	this software without specific prior written permission.

	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
	IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
	THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
	PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR 
	CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
	EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
	PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
	PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
	LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
	NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
	SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

package com.adobe.xml.syndication.generic
{

	import com.adobe.xml.syndication.rss.Category;
	import com.adobe.xml.syndication.rss.Item20;

	/**
	 * Class that abstracts out the specific characteristics of an RSS 2.0 item
	 * into a generic Item. You create an instance using an Item20 object,
	 * then you can access it in a generic way.
	 * 
	 * @langversion ActionScript 3.0
	 * @playerversion Flash 8.5
	 * @tiptext
	 */	
	public class RSS20Item
		implements IItem
	{
		private var item:Item20;

		/**
		 * Create a new RSS20Item instance.
		 *
		 * @param item An Item20 object that you want abstracted.
		 * 
		 * @langversion ActionScript 3.0
		 * @playerversion Flash 8.5
		 * @tiptext
		 */
		public function RSS20Item(item:Item20)
		{
			this.item = item;
		}

		/**
 		 * This item's title.
		 * 
		 * @langversion ActionScript 3.0
		 * @playerversion Flash 8.5
		 * @tiptext
		 */
		public function get title():String
		{
			return this.item.title;
		}

		/**
 		 * This item's link.
		 * 
		 * @langversion ActionScript 3.0
		 * @playerversion Flash 8.5
		 * @tiptext
		 */
		public function get link():String
		{
			return this.item.link;
		}

		/**
 		 * This item's unique ID.
		 * 
		 * @langversion ActionScript 3.0
		 * @playerversion Flash 8.5
		 * @tiptext
		 */
		public function get id():String
		{
			if (this.item.guid == null)
			{
				return null;
			}
			return this.item.guid.id;
		}

		/**
 		 * The date this item was published.
		 * 
		 * @langversion ActionScript 3.0
		 * @playerversion Flash 8.5
		 * @tiptext
		 */
		public function get date():Date
		{
			return this.item.pubDate;
		}

		/**
 		 * One or more authors of this item.
		 * 
		 * @langversion ActionScript 3.0
		 * @playerversion Flash 8.5
		 * @tiptext
		 */
		public function get authors():Array
		{
			if (this.item.creators == null) return null;
			var authors:Array = new Array();
			for each (var author:String in this.item.creators)
			{
				if (author == null) continue;
				var a:Author = new Author();
				a.name = author;
				authors.push(a);
			}
			return authors;
		}

		/**
 		 * One or more categories of this item.
		 * 
		 * @langversion ActionScript 3.0
		 * @playerversion Flash 8.5
		 * @tiptext
		 */
		public function get topics():Array
		{
			if (this.item.categories == null) return null;
			var categories:Array = new Array();
			for each (var cat:Category in this.item.categories)
			{
				for each (var innerCat:String in cat.path)
				{
					categories.push(innerCat);
				}
			}
			return categories;
		}

		/**
 		 * An excerpt or description of this item.
		 * 
		 * @langversion ActionScript 3.0
		 * @playerversion Flash 8.5
		 * @tiptext
		 */
		public function get excerpt():Excerpt
		{
			var excerpt:Excerpt = new Excerpt;
			if (this.item.description != null)
			{
				excerpt.type = "text";
				excerpt.value = this.item.description;
			}
			return excerpt;
		}

		public function get content():String
		{
			if (this.item.encodedContent == null) return null;
			return this.item.encodedContent;
		}

		/**
 		 * Any media associated with this item.
		 * 
		 * @langversion ActionScript 3.0
		 * @playerversion Flash 8.5
		 * @tiptext
		 */
		public function get media():Media
		{
			if (this.item.enclosure == null)
			{
				return null;
			}
			var media:Media = new Media();
			media.url = item.enclosure.url;
			media.length = item.enclosure.length;
			media.type = item.enclosure.type;
			return media;
		}
		
		public function get xml():XMLList
		{
			return item.xml;
		}
	}
}