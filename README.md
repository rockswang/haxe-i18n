i18n
====

i18n is a macro driven internationalization/localization toolkit for Haxe.

### Localization quick tour

1. 'using' I18n and call macro method I18n.init() at the entry point of your code.
2. Add '.i18n()' after all string literals to be externalized.
3. Build your project, strings will be extracted to "i18n_work/default/strings.xml", under your project root directory.
4. Then you can do translating based on strings.xml and store the translations into "i18n_work/&lt;locale&gt;/" folders.
5. Specify the target locale with macro compiler option I18n.locale(), e.g.: "--macro com.roxstudio.i18n.I18n.locale('zh')".
6. Rebuild the project, this time I18n will look up the corresponding translation and replace the original string literals with the translated version.

### Internationalization quick tour:

Almost the same procedure with localization, except two:

1. In step 5, simply use 'global' for the locale argument. This will build a multilingual application.
2. After I18n.init(), detect and set the desired locale, e.g.: I18n.setCurrentLocale(flash.system.Capabilities.language);

### Macro compiler options

I18n.locale(loc: String): set target locale, 'default', 'global' & arbitary custom locales e.g. 'zh', 'fr', can be used.

I18n.assets(path: String): set the output assets folder, by default it's "assets/i18n". The folder is for storing all locale sensitive resource files.

To set compiler options in NME project, simply add two lines in NMML file, e.g.:
```xml
    <compilerflag name="--macro com.roxstudio.i18n.I18n.locale('zh')" />
    <compilerflag name="--macro com.roxstudio.i18n.I18n.assets('res/i18n')" />
```

### The underneath code substitution

Assume I have original "i18n_work/default/strings.xml" like this:
```xml
<strings>
  <file path="Main.hx">
    <t id="Hello">Hello</t><!--line 12-->
  </file>
</strings>
```
And the Chinese translation is ready at "i18n_work/zh/strings.xml", like this:
```xml
<strings>
  <file path="Main.hx">
    <t id="Hello">你好</t>
  </file>
</strings>
```

When I target 'zh' locale and build the project, the original haxe code in Main.hx:
```haxe
textfield.text = "Hello".i18n();
```
will be transformed to (at compile-time):
```haxe
textfield.text = "你好";
```
When I target 'global' locale and build the project, the code will be transformed to:
```haxe
textfield.text = Global.str(0);
```
Global.str() is a run-time method for quick-access to the string mapping.

### Launch-time locale switching

While using 'global' locale, your app will gain the capability of launch-time locale switching. E.g.:
```haxe
    I18n.init();
    I18n.setCurrentLocale(flash.system.Capabilities.language);
```
If the desired locale is not supported, then it will fallback to 'default'.

### Run-time locale switching

Run-time locale switching is a little bit more tricky then launch-time approach, normally it needs to do some extra operations to handle the string changes, 
e.g. UI refreshing etc. Here's the approach used by I18n.
```haxe
    var textfield = new TextField();
    I18n.onChange(textfield.text = 'Hello'.i18n());
```
This will be transformd to:
```haxe
    var textfield = new TextField();
    var __i18n_callb__ = function() { textfield.text = Global.str(0); }
    Global.addListener("current code location", __i18n_callb__);
    __i18n_callb__();
```
And the "__i18n_callb__" will be invoked again if Global.setCurrentLocale() get called.

### Next step

* Sample projects, including a StablexUI sample

###License

####The MIT License

Copyright © 2012 roxstudio / rockswang

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rightsto use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
