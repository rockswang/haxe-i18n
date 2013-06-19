package com.roxstudio.i18n;

#if !macro

import nme.Assets;

#end

#if macro

import Lambda;
import sys.FileSystem;
import sys.io.File;

#end

import haxe.macro.Context;
import haxe.macro.Expr;

class I18n {


#if !macro

    public static var supportedLocales(get_supportedLocales, never): Array<String>;
    public static var currentLocale(default, set_currentLocale) : String = DEFAULT;
    public static var isGlobal(default, null): Bool;

    private static inline var DEFAULT = "default";

    private static var map: IntHash<String>;
    private static var assetsDir: String;
    private static var absenceResources: Hash<Int>;

    private function new() {
    }

    public static inline function _str(id: Int) : String {
        return map.get(id);
    }

    public static inline function _res(path: String) : String {
        var locPath = currentLocale + "/" + path;
        if (absenceResources.exists(locPath)) locPath = DEFAULT + "/" + path;
        return assetsDir + "/" + locPath;
    }

    private static inline function get_supportedLocales() : Array<String> {
        return mGetSupportedLocales();
    }

    public static function _init() : Void {
        isGlobal = mGetIsGlobal();
        if (isGlobal) {
            assetsDir = mGetAssetsDir();
            absenceResources = new Hash();
            for (s in mGetAbsenceResources()) absenceResources.set(s, 1);
            set_currentLocale(DEFAULT);
        }
    }

    private static function set_currentLocale(locale: String) : String {
        if (!isGlobal) {
            throw "currentLocale is only available for 'global' locale";
        }
        if (!Lambda.has(supportedLocales, locale)) {
            locale = DEFAULT;
        }
        if (currentLocale == locale && map != null) return locale;
        var path = assetsDir + "/" + locale + "/strings.xml";
        map = new IntHash();
        var s = Assets.getText(path);
        if (s != null && s.length > 0) {
            var xml = Xml.parse(s);
            for (n in xml.firstElement().elements()) {
                var id = Std.parseInt(n.get("id"));
                var val = n.firstChild().nodeValue;
                map.set(id, val);
            }
        }
        return currentLocale = locale;
    }

#end

/******************************************************************
*       Macro Methods
******************************************************************/

    @:macro public static function init() : Expr {
        if (mStrings != null) return Context.parse("{}", Context.currentPos()); // it's already initialized

        if (!FileSystem.exists(mWorkDir + "/" + DEFAULT)) mkdirs(mWorkDir + "/" + DEFAULT);
        var recentLocale = DEFAULT;
        if (FileSystem.exists(mWorkDir + "/recentLocale"))
            recentLocale = File.getContent(mWorkDir + "/recentLocale");
        if (recentLocale != mUseLocale) rmdir(mAssetsDir);
        File.saveContent(mWorkDir + "/recentLocale", mUseLocale);
        Context.onGenerate(postCompile);

        mLocales = [];
        for (dir in FileSystem.readDirectory(mWorkDir)) {
            if (FileSystem.isDirectory(mWorkDir + "/" + dir)) mLocales.push(dir);
        }

        mLookups = new Hash();
        var isglobal = mUseLocale == MGLOBAL;
        var locales = isglobal ? mLocales : [ DEFAULT, mUseLocale ];
        for (loc in locales) {
            var map = new Hash();
            if (FileSystem.exists(mWorkDir + "/" + loc + "/strings.xml")) {
                var xml = Xml.parse(File.getContent(mWorkDir + "/" + loc + "/strings.xml")).firstElement();
                for (file in xml.elementsNamed("file")) {
                    var path = file.get("path");
                    for (t in file.elementsNamed("t")) {
                        var id = t.get("id");
                        var val = t.firstChild().nodeValue;
                        map.set(path + "//" + id, val);
                    }
                }
            }
            mLookups.set(loc, map);
        }
        mAbsence = [];
        if (isglobal) {
            var allRes = listDir(mWorkDir + "/" + DEFAULT, "");
            for (loc in locales) {
                if (loc == DEFAULT) continue;
                var locRes = listDir(mWorkDir + "/" + loc, "");
                for (file in allRes) {
                    if (file != "strings.xml" && !Lambda.has(locRes, file)) mAbsence.push(loc + "/" + file);
                }
            }
        }

        mStrings = new Hash();

        return Context.parse("com.roxstudio.i18n.I18n._init()", Context.currentPos());
    }

    @:macro public static function str(s: ExprOf<String>) : Expr {
        var str = expr2Str(s);
        var path = Context.getPosInfos(s.pos).file;
        var id: Int;
        var key = path + "//" + lbEsc(str);
        var val = mStrings.get(key);
        var pos = ("" + s.pos).split(":")[1];
//        Context.warning("pos=" + s.pos + ",line=" + pos, s.pos);
        if (val != null) {
            val.pos.push(pos);
            id = val.id;
        } else {
            id = mCounter++;
            mStrings.set(key, { id: id, val: str, file: path, pos: [ pos ] });
        }
        return switch (mUseLocale) {
        case MGLOBAL:
            Context.parse("com.roxstudio.i18n.I18n._str(" + id + ")", s.pos);
        default:
            var val = mLookups.get(mUseLocale).get(key);
            if (val == null) val = mLookups.get(DEFAULT).get(key);
            if (val == null) val = str;
            Context.parse("'" + quoteEsc(val) + "'", s.pos);
        }
    }

    @:macro public static function res(path: ExprOf<String>) : Expr {
        var p = expr2Str(path);
        var defaultPath = mWorkDir + "/" + DEFAULT + "/" + p;
        if (!FileSystem.exists(defaultPath)) Context.error("Asset:" + defaultPath + " does not exist.", path.pos);
        return switch (mUseLocale) {
        case MGLOBAL:
            copy(defaultPath, mAssetsDir + "/" + DEFAULT + "/" + p);
            for (l in mLocales) {
                var locPath = l + "/" + p;
                if (FileSystem.exists(mWorkDir + "/" + locPath)) {
                    copy(mWorkDir + "/" + locPath, mAssetsDir + "/" + locPath);
                }
            }
            Context.parse("com.roxstudio.i18n.I18n._res('" + p + "')", path.pos);
        default:
            var locPath = mUseLocale + "/" + p;
            if (FileSystem.exists(mWorkDir + "/" + locPath)) {
                copy(mWorkDir + "/" + locPath, mAssetsDir + "/" + p);
            } else {
                copy(defaultPath, mAssetsDir + "/" + p);
            }
            Context.parse("'" + mAssetsDir + "/" + p + "'", path.pos);
        }
    }

    @:macro private static function mGetSupportedLocales() : Expr {
        var code = new StringBuf();
        code.add("[");
        if (mUseLocale == MGLOBAL)
            for (l in mLocales) code.add("'" + l + "',");
        code.add("]");
        return Context.parse(code.toString(), Context.currentPos());
    }

    @:macro private static function mGetAbsenceResources() : Expr {
        var code = new StringBuf();
        code.add("[");
        if (mUseLocale == MGLOBAL) {
            for (p in mAbsence) code.add("'" + p + "',");
        }
        code.add("]");
//        Context.warning("mGetAbsenceResources=" + code, Context.currentPos());
        return Context.parse(code.toString(), Context.currentPos());
    }

    @:macro private static function mGetAssetsDir() : Expr {
        return Context.parse("'" + mAssetsDir + "'", Context.currentPos());
    }

    @:macro private static function mGetIsGlobal() : Expr {
        return Context.parse("" + (mUseLocale == MGLOBAL), Context.currentPos());
    }

/******************************************************************
*       Compiler Options
******************************************************************/

#if macro

    public static function locale(locale: String) {
        mUseLocale = locale;
    }

    public static function assets(dir: String) {
        mAssetsDir = dir;
    }

#end

/******************************************************************
*       Private stuff
******************************************************************/

#if macro

    private static inline var DEFAULT = "default";
    private static inline var MGLOBAL = "global";
    private static inline var XML_HEAD = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\r\n";

    private static var mUseLocale: String = DEFAULT;
    private static var mAssetsDir: String = "assets/i18n";
    private static var mWorkDir: String = "i18n_work";
    private static var mStrings: Hash<MItem>; // className/id => MItem
    private static var mLookups: Hash<Hash<String>>; // locale => { className/id => String }
    private static var mLocales: Array<String>;
    private static var mAbsence: Array<String>;
    private static var mCounter: Int = 1;

    private static function postCompile(_) : Void {
//        Context.warning("postCompile=" + mUseLocale, Context.currentPos());
        var defLookup = mLookups.get(DEFAULT);
        var all: Array<MItem> = Lambda.array(mStrings);
        all.sort(function(i1: MItem, i2: MItem) : Int {
            return Reflect.compare(i1.file + "//" + i1.val, i2.file + "//" + i2.val);
        });
        var path: String = null;
        var fileNode: Xml = null;
        var strings = Xml.createElement("strings");
        for (i in all) {
            if (i.file != path) {
                if (fileNode != null) fileNode.addChild(Xml.createPCData("\r\n  "));
                path = i.file;
                strings.addChild(Xml.createPCData("\r\n  "));
                fileNode = Xml.createElement("file");
                fileNode.set("path", path);
                strings.addChild(fileNode);
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
        strings.addChild(Xml.createPCData("\r\n"));
        File.saveContent(mWorkDir + "/" + DEFAULT + "/strings.xml", XML_HEAD + strings.toString());

        if (mUseLocale != MGLOBAL) return;

        for (loc in mLocales) {
            strings = Xml.createElement("strings");
            var lookup = mLookups.get(loc);
            for (key in mStrings.keys()) {
                var item = mStrings.get(key);
                var val = lookup.get(key);
                if (val == null) val = defLookup.get(key);
                if (val == null) val = item.val;
                var id = item.id;
                var t = Xml.createElement("t");
                t.set("id", "" + id);
                t.addChild(Xml.createPCData(val));
                strings.addChild(t);
            }
            mkdirs(mAssetsDir + "/" + loc);
            File.saveContent(mAssetsDir + "/" + loc + "/strings.xml", strings.toString());
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
        if (str == null) Context.error("Constant string expected", expr.pos);
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

#if macro

private typedef MItem = {
    id: Int,
    val: String,
    file: String,
    pos: Array<String>
};

#end
