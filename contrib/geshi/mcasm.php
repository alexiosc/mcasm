<?php
/*************************************************************************************
 * mcasm.php
 * -----
 * Author: Alexios Chouchoulas (alexios@bedroomlan.org)
 * 
 * Derived from c.php:
 *
 * Author: Nigel McNie (nigel@geshi.org)
 * Contributors:
 *  - Jack Lloyd (lloyd@randombit.net)
 * Copyright: (c) 2004 Nigel McNie (http://qbnz.com/highlighter/)
 * Release Version: 1.0.7.20
 * Date Started: 2004/06/04
 *
 * C language file for GeSHi.
 *
 * CHANGES
 * -------
 * 2004/XX/XX (1.0.4)
 *   -  Added a couple of new keywords (Jack Lloyd)
 * 2004/11/27 (1.0.3)
 *   -  Added support for multiple object splitters
 * 2004/10/27 (1.0.2)
 *   -  Added support for URLs
 * 2004/08/05 (1.0.1)
 *   -  Added support for symbols
 * 2004/07/14 (1.0.0)
 *   -  First Release
 *
 * TODO (updated 2004/11/27)
 * -------------------------
 *  -  Get a list of inbuilt functions to add (and explore C more
 *     to complete this rather bare language file
 *
 *************************************************************************************
 *
 *     This file is part of GeSHi.
 *
 *   GeSHi is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation; either version 2 of the License, or
 *   (at your option) any later version.
 *
 *   GeSHi is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details.
 *
 *   You should have received a copy of the GNU General Public License
 *   along with GeSHi; if not, write to the Free Software
 *   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 ************************************************************************************/

$language_data = array (
	'LANG_NAME' => 'mcasm',
	'COMMENT_SINGLE' => array(1 => '//'),
	'COMMENT_MULTI' => array('/*' => '*/'),
	'CASE_KEYWORDS' => GESHI_CAPS_NO_CHANGE,
	'QUOTEMARKS' => array("'", '"'),
	'ESCAPE_CHAR' => '\\',
	'KEYWORDS' => array(
		2 => array(
			   'cond', 'field', 'signal', 'start', 'uaddr'
			   ),
		3 => array(
			   '#define', '#ifdef', '#if', '#ifndef', '#endif'
			   ),
			    ),
	'SYMBOLS' => array(
			   '(', ')', '=', '-',
			   ),
	'CASE_SENSITIVE' => array(
				  GESHI_COMMENTS => true,
				  1 => false,
				  2 => false,
				  3 => false,
				  4 => false,
				  ),
	'STYLES' => array(
			  'KEYWORDS' => array(
					      1 => 'color: #b1b100;',
					      2 => 'color: #000000; font-weight: bold;',
					      3 => 'color: #000066;',
					      4 => 'color: #993333;'
					      ),
			  'COMMENTS' => array(
					      1 => 'color: #808080; font-style: italic;',
					      2 => 'color: #339933;',
					      'MULTI' => 'color: #808080; font-style: italic;'
					      ),
			  'ESCAPE_CHAR' => array(
						 0 => 'color: #000099; font-weight: bold;'
						 ),
			  'BRACKETS' => array(
					      0 => 'color: #66cc66;'
					      ),
			  'STRINGS' => array(
					     0 => 'color: #ff0000;'
					     ),
			  'NUMBERS' => array(
					     0 => 'color: #cc66cc;'
					     ),
			  'METHODS' => array(
					     1 => 'color: #202020;',
					     2 => 'color: #202020;'
					     ),
			  'SYMBOLS' => array(
					     0 => 'color: #66cc66;'
					     ),
			  'REGEXPS' => array(
					     0 => 'color: #007800;',
					     1 => 'color: #780000;',
					     ),
			  'SCRIPT' => array(
					    )
			  ),
	'URLS' => array(
			1 => '',
			2 => '',
			3 => '',
			4 => ''
			),
	'OOLANG' => false,
	'OBJECT_SPLITTERS' => array(
				    ),
	'REGEXPS' =>
	array(
	      0 => array(
			 GESHI_SEARCH => '(\S+)(\s*=)',
			 GESHI_REPLACE => '\\1',
			 GESHI_MODIFIERS => '',
			 GESHI_BEFORE => '',
			 GESHI_AFTER => '\\2',
			 ),
	      ),
	1 => array(
		   GESHI_SEARCH => '^(\s*cond\s*)(\S+)(\s*:)',
		   GESHI_REPLACE => '\\2',
		   GESHI_MODIFIERS => '',
		   GESHI_BEFORE => '\\1',
		   GESHI_AFTER => '\\3',
		   ),
	'STRICT_MODE_APPLIES' => GESHI_NEVER,
	'SCRIPT_DELIMITERS' => array(
				     ),
	'HIGHLIGHT_STRICT_BLOCK' => array(
					  ),
	'TAB_WIDTH' => 4
);

?>
