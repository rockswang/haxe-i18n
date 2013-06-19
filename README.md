i18n
====

i18n is a macro driven internationalization/localization toolkit for Haxe.

### Localization quick tour

1. Call macro method I18n.init() at the entry point of your code.
2. Enclose all string literals to be externalized with macro method I18n.str(). 
3. Build your project, strings will be extracted to "i18n_work/default/strings.xml", under your project root directory.
4. Then you can do translating based on strings.xml and store the translations into "i18n_work/&lt;locale&gt;/" folders.
5. Specify the target locale with macro compiler option I18n.locale(), e.g.: "--macro com.roxstudio.i18n.I18n.locale('zh')".
6. Rebuild the project, this time I18n will look up the corresponding translation and replace the original string literals with the translated version.

### Internationalization quick tour:

Almost the same procedure with localization, except in step 5, simply use 'global' for the locale argument. This will build a multilingual application.

### Macro compiler options

I18n.locale(loc: String): set target locale, 'default', 'global' & arbitary custom locales e.g. 'zh', 'fr', can be used.

I18n.assets(path: String): set the output assets folder, by default it's "assets/i18n". The folder is for storing all locale sensitive resource files.

To set compiler options in NME project, simple add two lines in NMML file, e.g.:
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
textfield.text = I18n.str("Hello");
```
will be transformed to (at compile-time):
```haxe
textfield.text = "你好";
```
When I target 'global' locale and build the project, the code will be transformed to:
```haxe
textfield.text = I18n._str(0);
```
I18n._str() is a run-time method for accessing the string mapping.

### The multilingual application

While using 'global' locale, your app will gain the capability of launch-time locale switching. E.g.:
```haxe
    I18n.init();
    I18n.currentLocale = nme.system.Capabilities.language;
```
If the desired locale is not supported, then it will fallback to 'default'.

