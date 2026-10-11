# Builds / reads Witcher 3 5.0 string files (.w3strings, UTF-8 generation v164, English key).
# Format ported from Witcher3StringEditor (MIT, https://github.com/0x7A2C9E5D/Witcher3StringEditor),
# Witcher3StringEditor.Serializers/W3Strings/*.cs.
#
#   Build:  .\w3strings.ps1 -Source strings.txt -Out en.w3strings -FirstId 2112230000
#           strings.txt: one "key|text" per line (blank lines and lines starting with # are skipped)
#   Lookup: .\w3strings.ps1 -Read en.w3strings -Key panel_Mods
param(
    [string]$Source, [string]$Out, [uint32]$FirstId = 2112230000,
    [string]$Read, [string]$Key
)
$ErrorActionPreference = "Stop"

Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;

public static class W3Strings
{
    const uint LangKey = 0x43975139;   // English
    const uint Magic = 0x79321793;     // English
    const uint Version = 164;          // UTF-8 generation

    public static uint Hash(string key)
    {
        uint h = 0;
        foreach (char c in key.ToLowerInvariant()) h = unchecked(h * 31 + c);
        return h;
    }

    static byte[] Count(uint v)
    {
        if (v == 0) return new byte[] { 0x80 };
        int len = 1;
        for (uint r = v >> 6; r > 0; r >>= 7) len++;
        var b = new byte[len];
        b[0] = (byte)(v & 0x3F);
        if (len > 1) b[0] |= 0x40;
        uint rem = v >> 6;
        for (int i = 1; i < len - 1; i++) { b[i] = (byte)((rem & 0x7F) | 0x80); rem >>= 7; }
        if (len > 1) b[len - 1] = (byte)rem;
        return b;
    }

    static uint ReadCount(BinaryReader r)
    {
        int first = r.ReadByte();
        if ((first & 0x40) == 0) return (uint)(first & 0x3F);
        ulong value = (ulong)(first & 0x3F);
        for (int length = 2; length <= 5; length++)
        {
            int next = r.ReadByte();
            value |= (ulong)(next & 0x7F) << (6 + 7 * (length - 2));
            if ((next & 0x80) == 0) return (uint)value;
        }
        throw new InvalidDataException("bad count");
    }

    // XOR stream keyed by the text length; the same call encodes and decodes.
    static void Xor(byte[] b, int offset, int length)
    {
        ushort k = (ushort)((Magic >> 8) & 0xFFFF);
        for (int i = 0; i < length; i++)
        {
            uint ck = (uint)(length + 1) * k;
            b[offset + i] ^= (byte)ck;
            k = (ushort)(((k << 1) | (k >> 15)) & 0xFFFF);
        }
    }

    public static void Build(string[] keys, string[] texts, uint firstId, string outPath)
    {
        int n = keys.Length;
        var ids = new uint[n];
        var enc = new byte[n][];
        var off = new uint[n];
        uint cursor = 0;
        for (int i = 0; i < n; i++)
        {
            ids[i] = firstId + (uint)i;
            enc[i] = Encoding.UTF8.GetBytes(texts[i]);
            Xor(enc[i], 0, enc[i].Length);
            off[i] = cursor;
            cursor += (uint)enc[i].Length + 1;
        }
        using (var w = new BinaryWriter(File.Create(outPath)))
        {
            w.Write(Encoding.ASCII.GetBytes("RTSW"));
            w.Write(Version);
            w.Write((ushort)(LangKey >> 16));

            w.Write(Count((uint)n));
            foreach (int i in Enumerable.Range(0, n).OrderBy(i => ids[i] ^ Magic))
            {
                w.Write(ids[i] ^ Magic);
                w.Write(off[i]);
                w.Write((uint)enc[i].Length);
            }

            w.Write(Count((uint)n));
            foreach (int i in Enumerable.Range(0, n).OrderBy(i => Hash(keys[i])))
            {
                w.Write(Hash(keys[i]));
                w.Write(ids[i] ^ Magic);
            }

            w.Write(Count(cursor));
            for (int i = 0; i < n; i++) { w.Write(enc[i]); w.Write((byte)0); }

            w.Write((ushort)(LangKey & 0xFFFF));
        }
    }

    // Returns the text stored under a key, or null.
    public static string Lookup(string path, string key)
    {
        using (var r = new BinaryReader(File.OpenRead(path)))
        {
            if (Encoding.ASCII.GetString(r.ReadBytes(4)) != "RTSW") throw new InvalidDataException("not RTSW");
            uint version = r.ReadUInt32();
            if (version < 164) throw new InvalidDataException("only the UTF-8 generation (v164+) is supported");
            r.ReadUInt16();
            uint n = ReadCount(r);
            var offs = new Dictionary<uint, uint[]>();
            for (uint i = 0; i < n; i++) { uint id = r.ReadUInt32(); offs[id] = new[] { r.ReadUInt32(), r.ReadUInt32() }; }
            uint k = ReadCount(r);
            uint want = Hash(key);
            uint found = 0; bool hit = false;
            for (uint i = 0; i < k; i++) { uint h = r.ReadUInt32(); uint id = r.ReadUInt32(); if (h == want) { found = id; hit = true; } }
            uint size = ReadCount(r);
            byte[] buf = r.ReadBytes((int)size);
            if (!hit) return null;
            uint[] e = offs[found];
            var text = new byte[e[1]];
            Array.Copy(buf, e[0], text, 0, e[1]);
            Xor(text, 0, text.Length);
            return Encoding.UTF8.GetString(text);
        }
    }
}
"@

if ($Read) {
    $text = [W3Strings]::Lookup((Resolve-Path $Read).Path, $Key)
    if ($null -eq $text) { "<missing>" } else { $text }
    return
}

$keys = New-Object System.Collections.Generic.List[string]
$texts = New-Object System.Collections.Generic.List[string]
foreach ($line in [IO.File]::ReadAllLines((Resolve-Path $Source).Path, [Text.Encoding]::UTF8)) {
    if ($line.Trim() -eq "" -or $line.StartsWith("#")) { continue }
    $i = $line.IndexOf("|")
    if ($i -lt 1) { throw "Bad line (expected key|text): $line" }
    $keys.Add($line.Substring(0, $i)); $texts.Add($line.Substring($i + 1))
}
if ([IO.Path]::IsPathRooted($Out)) { $outFull = $Out } else { $outFull = [IO.Path]::GetFullPath((Join-Path (Get-Location) $Out)) }
[W3Strings]::Build($keys.ToArray(), $texts.ToArray(), $FirstId, $outFull)
"Wrote $($keys.Count) strings to $outFull"
