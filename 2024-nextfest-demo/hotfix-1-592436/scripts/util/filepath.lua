--- Path manipulation and file queries.

-- KLEI: Adapted from Penlight:
-- https://github.com/stevedonovan/Penlight
-- We only use / path separator, no LuaFileSystem, no attributes, and other changes.
--
--
-- This is modelled after Python's os.path library (10.1); see @{04-paths.md|the Guide}.
--
-- Dependencies: `pl.utils`, `lfs`
-- @module pl.path

--[[
MIT license
Copyright (C) 2009-2016 Steve Donovan, David Manura.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--]]

-- imports and locals
local _G = _G
local sub = string.sub
local getenv = os.getenv
local tmpnam = os.tmpname
local attributes, currentdir, link_attrib
local package = package
local io = io
local append = table.insert
local ipairs = ipairs
local LIST_FILES = require "util.listfilesenum"


local currentdir = function() return BASE_PATH end

local function assert_arg (n,val,tp,verify,msg,lev)
	if type(val) ~= tp then
		error(("argument %d expected a '%s', got a '%s'"):format(n,tp,type(val)),lev or 2)
	end
	if verify and not verify(val) then
		error(("argument %d: '%s' %s"):format(n,val,msg),lev or 2)
	end
end

local assert_string = function (n,val)
	assert_arg(n,val,'string',nil,nil,3)
end

--- split a string into a list of strings separated by a delimiter.
-- @param s The input string
-- @param re A Lua string pattern; defaults to '%s+'
-- @param plain don't use Lua patterns
-- @param n optional maximum number of splits
-- @return a list-like table
-- @raise error if s is not a string
local split = function(s,re,plain,n)
	assert_string(1,s)
	local find,sub,append = string.find, string.sub, table.insert
	local i1,ls = 1,{}
	if not re then re = '%s+' end
	if re == '' then return {s} end
	while true do
		local i2,i3 = find(s,re,i1,plain)
		if not i2 then
			local last = sub(s,i1)
			if last ~= '' then append(ls,last) end
			if #ls == 1 and ls[1] == '' then
				return {}
			else
				return ls
			end
		end
		append(ls,sub(s,i1,i2-1))
		if n and #ls == n then
			ls[#ls] = sub(s,i1)
			return ls
		end
		i1 = i3+1
	end
end

local attrib
local path = {}

local function at(s,i)
	return sub(s,i,i)
end

path.sep = '/'

local sep = path.sep

--- path separator for this platform.
-- @class field
-- @name path.sep

--- separator for PATH for this platform
-- @class field
-- @name path.dirsep

--- given a path, return the directory part and a file part.
-- if there's no directory part, the first value will be empty
-- @string P A file path
function path.splitpath(P)
	assert_string(1,P)
	local i = #P
	local ch = at(P,i)
	while i > 0 and ch ~= sep do
		i = i - 1
		ch = at(P,i)
	end
	if i == 0 then
		return '',P
	else
		return sub(P,1,i-1), sub(P,i+1)
	end
end

--- return an absolute path.
-- @string P A file path
-- @string[opt] pwd optional start path to use (default is current dir)
function path.abspath(P,pwd)
	assert_string(1,P)
	if pwd then assert_string(2,pwd) end
	local use_pwd = pwd ~= nil
	if not use_pwd and not currentdir then return P end
	P = P:gsub('[\\/]$','')
	pwd = pwd or currentdir()
	if not path.isabs(P) then
		P = path.join(pwd,P)
	end
	return path.normpath(P)
end

--- given a path, return the root part and the extension part.
-- if there's no extension part, the second value will be empty
-- @string P A file path
-- @treturn string root part
-- @treturn string extension part (maybe empty)
function path.splitext(P)
	assert_string(1,P)
	local i = #P
	local ch = at(P,i)
	while i > 0 and ch ~= '.' do
		if ch == sep then
			return P,''
		end
		i = i - 1
		ch = at(P,i)
	end
	if i == 0 then
		return P,''
	else
		return sub(P,1,i-1),sub(P,i)
	end
end

--- return the directory part of a path
-- @string P A file path
function path.dirname(P)
	assert_string(1,P)
	local p1,p2 = path.splitpath(P)
	return p1
end

--- return the file part of a path
-- @string P A file path
function path.basename(P)
	assert_string(1,P)
	local p1,p2 = path.splitpath(P)
	return p2
end

--- get the extension part of a path.
-- @string P A file path
function path.extension(P)
	assert_string(1,P)
	local p1,p2 = path.splitext(P)
	return p2
end

--- is this an absolute path?.
-- @string P A file path
function path.isabs(P)
	assert_string(1,P)
	local c = at(P,1)
	return c ~= sep
end

--- return the path resulting from combining the individual paths.
-- empty elements (except the last) will be ignored.
-- @string p1 A file path
-- @string ... more file paths
function path.join(p,...)
	assert_string(1,p)
	local n = select('#',...)
	if n > 0 then
		for i = 1,n do
			local pi = select( i, ... )
			assert_string(i,pi)
			--assert( not path.isabs(pi), pi)
			local endc = at(p,#p)
			if endc ~= path.sep and endc ~= "" then
				p = p .. path.sep
			end
			p = p .. pi
		end
	end
	return p
end

function path.normslashes(P)
	assert_string(1,P)

	return (P:gsub('\\', '/'))
end

local np_gen1,np_gen2 = '([^SEP]+)SEP(%.%.SEP?)','SEP+%.?SEP'
local np_pat1, np_pat2

--- normalize a path name.
--  A//B, A/./B and A/foo/../B all become A/B.
-- @string P a file path
function path.normpath(P)
	assert_string(1,P)

	P = path.normslashes(P)

	if not np_pat1 then
		np_pat1 = np_gen1:gsub('SEP',sep)
		np_pat2 = np_gen2:gsub('SEP',sep)
	end
	local k
	repeat -- /./ -> /
		P,k = P:gsub(np_pat2,sep)
	until k == 0
	repeat -- A/../ -> (empty)
		local oldP = P
		P,k = P:gsub(np_pat1,function(D, up)
			if D == '..' then return nil end
			if D == '.' then return up end
			return ''
		end)
	until k == 0 or oldP == P
	if P == '' then P = '.' end
	return P
end

local function ATS (P)
	if at(P,#P) ~= path.sep then
		P = P..path.sep
	end
	return path.normslashes(P)
end

--- relative path from current directory or optional start point
-- @string P a path
-- @string[opt] start optional start point (default current directory)
function path.relpath (P,start)
	assert_string(1,P)
	if start then assert_string(2,start) end
	local normslashes,min,append = path.normslashes, math.min, table.insert
	P = normslashes(path.abspath(P,start))
	start = start or currentdir()
	start = normslashes(start)
	local startl, Pl = split(start,sep), split(P,sep)
	local n = min(#startl,#Pl)
	local k = n+1 -- default value if this loop doesn't bail out!
	for i = 1,n do
		if startl[i] ~= Pl[i] then
			k = i
			break
		end
	end
	local rell = {}
	for i = 1, #startl-k+1 do rell[i] = '..' end
	if k <= #Pl then
		for i = k,#Pl do append(rell,Pl[i]) end
	end
	return table.concat(rell,sep)
end


--- return the largest common prefix path of two paths.
-- @string path1 a file path
-- @string path2 a file path
function path.common_prefix (path1,path2)
	assert_string(1,path1)
	assert_string(2,path2)
	path1, path2 = path.normslashes(path1), path.normslashes(path2)
	-- get them in order!
	if #path1 > #path2 then path2,path1 = path1,path2 end
	for i = 1,#path1 do
		local c1 = at(path1,i)
		if c1 ~= at(path2,i) then
			local cp = path1:sub(1,i-1)
			if at(path1,i-1) ~= sep then
				cp = path.dirname(cp)
			end
			return cp
		end
	end
	if at(path2,#path1+1) ~= sep then
		path1 = path.dirname(path1)
	end
	return path1
end

function path.list_files( dir, filename, recurse, t )
	if t == nil then
		t = {}
	end

	local files = TheSim:ListFiles( dir, filename )
	for k, filename in pairs(files) do
		table.insert( t, path.join( dir, filename ))
	end

	if recurse then
		local subdirs = TheSim:ListFiles( dir, "*", LIST_FILES.DIRS)
		for k, subdir in pairs(subdirs) do
			path.list_files( path.join( dir, subdir ), filename, recurse, t )
		end
	end

	return t
end


return path
