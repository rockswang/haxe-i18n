package com.roxstudio.i18n;

import haxe.macro.Context;
import haxe.macro.Expr;

#if macro

import sys.FileSystem;
import sys.io.File;

#end

#if haxe3

private typedef Hash<T> = Map<String, T>;

#end

private typedef Item = {
    id: Int,
    val: String,
    file: String,
    pos: Array<String>
}

class I18n {

/******************************************************************
*       Macro Methods
******************************************************************/

    #if haxe3 macro #else @:macro #end
    public static function init() : Expr {
//        trace("I18n.init()");
        if (initialized) return Context.parse("{}", Context.currentPos()); // Already initialized
        // make working directory
        if (!FileSystem.exists(workDir + "/" + DEFAULT))
            mkdirs(workDir + "/" + DEFAULT);
        // recentLocale is the locale used by previous build
        var recentLocale = DEFAULT;
        if (FileSystem.exists(workDir + "/recentLocale"))
            recentLocale = File.getContent(workDir + "/recentLocale");
        if (recentLocale != useLocale) rmdir(assetsDir);
        File.saveContent(workDir + "/recentLocale", useLocale);
        // register post-compile callback
        Context.onGenerate(postCompile);
        // scan for all available locale folders
        for (dir in FileSystem.readDirectory(workDir)) {
            if (FileSystem.isDirectory(workDir + "/" + dir)) locales.push(dir);
        }

        var isglobal = useLocale == GLOBAL;
        // make sure only necessary strings.xml are loaded
        var locales = isglobal ? locales : [ DEFAULT, useLocale ];
        for (loc in locales) {
            var map = new Hash();
            if (FileSystem.exists(workDir + "/" + loc + "/strings.xml")) {
                var xml = Xml.parse(File.getContent(workDir + "/" + loc + "/strings.xml")).firstElement();
                for (file in xml.elementsNamed("file")) {
                    var path = file.get("path");
                    for (t in file.elementsNamed("t")) {
                        var id = t.get("id");
                        var val = t.firstChild().nodeValue;
                        map.set(path + "//" + id, val);
                    }
                }
            }
            lookups.set(loc, map);
        }
        if (isglobal) {
            // check for absence resources and build a fallback lookup
            var allRes = listDir(workDir + "/" + DEFAULT, "");
            for (loc in locales) {
                if (loc == DEFAULT) continue;
                var locRes = listDir(workDir + "/" + loc, "");
                for (file in allRes) {
                    if (file != "strings.xml" && !Lambda.has(locRes, file))
                        absence.push(loc + "/" + file);
                }
            }
        }

        initialized = true;
        return Context.parse(isglobal ? "com.roxstudio.i18n.Global.init()" : "{}", Context.currentPos());
    }

    #if haxe3 macro #else @:macro #end
    public static function i18n(s: ExprOf<String>) : Expr {
        if (!initialized) throw "Call I18n.init()";
        var str = expr2Str(s);
        var path = Context.getPosInfos(s.pos).file;
        var id: Int;
        var key = path + "//" + lbEsc(str);
        var val = strings.get(key);
        var pos = ("" + s.pos).split(":")[1];
        if (val != null) {
            val.pos.push(pos);
            id = val.id;
        } else {
            id = counter++;
            strings.set(key, { id: id, val: str, file: path, pos: [ pos ] });
        }
        return switch (useLocale) {
        case GLOBAL:
            Context.parse("com.roxstudio.i18n.Global.str(" + id + ")", s.pos);
        default:
            var val = lookups.get(useLocale).get(key);
            if (val == null) val = lookups.get(DEFAULT).get(key);
            if (val == null) val = str;
            Context.parse("'" + quoteEsc(val) + "'", s.pos);
        }
    }

    #if haxe3 macro #else @:macro #end
    public static function i18nRes(path: ExprOf<String>) : Expr {
        if (!initialized) throw "Call I18n.init()";
        var p = expr2Str(path);
        var defaultPath = workDir + "/" + DEFAULT + "/" + p;
        if (!FileSystem.exists(defaultPath)) Context.error("Asset:" + defaultPath + " does not exist.", path.pos);
        return switch (useLocale) {
        case GLOBAL:
            copy(defaultPath, assetsDir + "/" + DEFAULT + "/" + p);
            for (l in locales) {
                var locPath = l + "/" + p;
                if (FileSystem.exists(workDir + "/" + locPath)) {
                    copy(workDir + "/" + locPath, assetsDir + "/" + locPath);
                }
            }
            Context.parse("com.roxstudio.i18n.Global.res('" + p + "')", path.pos);
        default:
            var locPath = useLocale + "/" + p;
            if (FileSystem.exists(workDir + "/" + locPath)) {
                copy(workDir + "/" + locPath, assetsDir + "/" + p);
            } else {
                copy(defaultPath, assetsDir + "/" + p);
            }
            Context.parse("'" + assetsDir + "/" + p + "'", path.pos);
        }
    }

    #if haxe3 macro #else @:macro #end
    public static function onChange(e: Expr) : Expr {
        var key = "" + e.pos;
        var ln = key.split(":")[1];
        var varname = "__i18n_callb__" + ln + "__" + Std.random(100000000) + "__";
        var callb: Expr = switch (e.expr) {
        case EFunction(n, f):
            n == null && f.args.length == 0 && f.ret == null && f.params.length == 0 ? e : null;
        default: null;
        }
        if (callb == null) {
            callb = { expr: EFunction(null, { args: [], ret: null, params: [], expr: e }), pos: e.pos };
        }
        var line1 = { expr: EVars([ { name: varname, type: null, expr: callb } ]), pos: e.pos };
        var line2 = Context.parse("com.roxstudio.i18n.Global.addListener('" + key + "', " + varname + ")", e.pos);
        var line3 = Context.parse(varname + "()", e.pos);
        return { expr: EBlock([ line1, line2, line3 ]), pos: e.pos };
    }

    #if haxe3 macro #else @:macro #end
    public static function getSupportedLocales() : Expr {
        var code = new StringBuf();
        code.add("[");
        if (useLocale == GLOBAL)
            for (l in locales) code.add("'" + l + "',");
        code.add("]");
//        trace("I18n.getSupportedLocales=" + code);
        return Context.parse(code.toString(), Context.currentPos());
    }

    #if haxe3 macro #else @:macro #end
    public static function setCurrentLocale(locExpr: Expr) : Expr {
        var field = Context.parse("com.roxstudio.i18n.Global.setCurrentLocale", locExpr.pos);
        return { expr: ECall(field, [ locExpr ]), pos: locExpr.pos };
    }

    #if haxe3 macro #else @:macro #end
    public static function getAbsenceResources() : Expr {
        var code = new StringBuf();
        code.add("[");
        if (useLocale == GLOBAL) {
            for (p in absence) code.add("'" + p + "',");
        }
        code.add("]");
        return Context.parse(code.toString(), Context.currentPos());
    }

    #if haxe3 macro #else @:macro #end
    public static function getAssetsDir() : Expr {
        return Context.parse("'" + assetsDir + "'", Context.currentPos());
    }

/******************************************************************
*       Compiler Options
******************************************************************/

#if macro

    public static function locale(locale: String) {
//        trace("I18n.locale = " + locale);
        useLocale = locale;
    }

    public static function assets(dir: String) {
//        trace("I18n.assets = " + dir);
        assetsDir = dir;
    }

#end

/******************************************************************
*       Private stuff
******************************************************************/

#if macro

    private static inline var DEFAULT = "default";
    private static inline var GLOBAL = "global";
    private static inline var XML_HEAD = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\r\n";

    private static var useLocale: String = DEFAULT;
    private static var assetsDir: String = "assets/i18n";
    private static var workDir: String = "i18n_work";
    private static var strings: Hash<Item> = new Hash(); // filepath//id => Item
    private static var lookups: Hash<Hash<String>> = new Hash(); // locale => { filepath//id => String }
    private static var locales: Array<String> = [];
    private static var absence: Array<String> = [];
    private static var initialized: Bool = false;
    private static var counter: Int = 1;

    private static function postCompile(_) : Void {
//        Context.warning("postCompile=" + useLocale, Context.currentPos());
        var defLookup = lookups.get(DEFAULT);
        var all: Array<Item> = Lambda.array(strings);
        all.sort(function(i1: Item, i2: Item) : Int {
            return Reflect.compare(i1.file + "//" + i1.val, i2.file + "//" + i2.val);
        });
        var path: String = null;
        var fileNode: Xml = null;
        var str = Xml.createElement("strings");
        for (i in all) {
            if (i.file != path) {
                if (fileNode != null) fileNode.addChild(Xml.createPCData("\r\n  "));
                path = i.file;
                str.addChild(Xml.createPCData("\r\n  "));
                fileNode = Xml.createElement("file");
                fileNode.set("path", path);
                str.addChild(fileNode);
            }
            fileNode.addChild(Xml.createPCData("\r\n    "));
            var t = Xml.createElement("t");
            var k = lbEsc(i.val);
            t.set("id", k);
            var val = defLookup.get(i.file + "//" + k);
            if (val == null) val = i.val;
            t.addChild(Xml.createPCData(val));
            fileNode.addChild(t);
            var lineinfo = new StringBuf();
            lineinfo.add("line ");
            for (l in 0...i.pos.length) { if (l > 0) lineinfo.add(", "); lineinfo.add(i.pos[l]); }
            fileNode.addChild(Xml.createComment(lineinfo.toString()));
        }
        if (fileNode != null) fileNode.addChild(Xml.createPCData("\r\n  "));
        str.addChild(Xml.createPCData("\r\n"));
        File.saveContent(workDir + "/" + DEFAULT + "/strings.xml", XML_HEAD + str.toString());

        if (useLocale != GLOBAL) return;

        for (loc in locales) {
            str = Xml.createElement("strings");
            var lookup = lookups.get(loc);
            for (key in strings.keys()) {
                var item = strings.get(key);
                var val = lookup.get(key);
                if (val == null) val = defLookup.get(key);
                if (val == null) val = item.val;
                var id = item.id;
                var t = Xml.createElement("t");
                t.set("id", "" + id);
                t.addChild(Xml.createPCData(val));
                str.addChild(t);
            }
            mkdirs(assetsDir + "/" + loc);
            File.saveContent(assetsDir + "/" + loc + "/strings.xml", str.toString());
        }
    }

    private static function mkdirs(path: String) {
//        Context.warning("mkdirs=" + path, Context.currentPos());
        var arr = path.split("/");
        var dir = "";
        for (i in 0...arr.length) {
            dir += arr[i];
            if (!FileSystem.exists(dir) || !FileSystem.isDirectory(dir)) {
                FileSystem.createDirectory(dir);
            }
            dir += "/";
        }
    }

    private static function rmdir(path: String) {
//        Context.warning("rmdir=" + path, Context.currentPos());
        if (!FileSystem.exists(path) || !FileSystem.isDirectory(path)) return;
        for (name in FileSystem.readDirectory(path)) {
            var sub = path + "/" + name;
            if (FileSystem.isDirectory(sub)) {
                rmdir(sub);
            } else {
                FileSystem.deleteFile(sub);
            }
        }
        FileSystem.deleteDirectory(path);

    }

    private static function copy(src: String, dest: String) {
//        Context.warning("copy " + src+ " to " + dest, Context.currentPos());
        if (FileSystem.exists(dest)) {
            var fs1 = FileSystem.stat(src);
            var fs2 = FileSystem.stat(dest);
            if (fs1.mtime.getTime() <= fs2.mtime.getTime()) return;
        }
        var idx = dest.lastIndexOf("/");
        if (idx > 0) mkdirs(dest.substr(0, idx));
        File.copy(src, dest);
    }

    private static inline function expr2Str(expr: ExprOf<String>) : String {
        var str: String = null;
        switch (expr.expr) {
        case EConst(c):
            switch (c) {
            case CString(s): str = s;
            default:
            }
        default:
        }
        if (str == null) {
            Context.error("Constant string expected", expr.pos);
        }
        return str;
    }

    private static function listDir(path: String, prefix: String, ?out: Array<String>) {
        if (out == null) out = [];
        for (file in FileSystem.readDirectory(path)) {
            if (FileSystem.isDirectory(path + "/" + file)) {
                listDir(path + "/" + file, prefix + file + "/", out);
            } else {
                out.push(prefix + file);
            }
        }
        return out;
    }

    private static inline function quoteEsc(s: String) : String {
        return StringTools.replace(s, "'", "\\'");
    }

    private static inline function lbEsc(s: String) : String {
        s = StringTools.replace(s, "\r", "\\r");
        s = StringTools.replace(s, "\n", "\\n");
        return s;
    }

#end

}
