--imports--
local cqueues = require"cqueues"
local errno = require"cqueues.errno"
local newreq = require "http.request"
local headers = require"http.headers"
local reason = require"http.h1_reason_phrases"
local httputil = require "http.util"
local json = require"rapidjson"
local util = require"novus.util"
local const = require"novus.const"
local lpeg = util.lpeg
local Date = util.Date
local JSON = "application/json"
local gettime = cqueues.monotime
local time, difftime, date = os.time, os.difftime, os.date
local insert, concat = table.insert, table.concat
local next, tonumber = next, tonumber
local setmetatable = setmetatable
local max = math.max
local print = print
local pcall = pcall
local tostring = tostring

--start-module--
local _ENV = {}

URL = const.api.endpoint
USER_AGENT = ("DiscordBot (%s, %s) lua-version:\"%s\""):format(const.homepage,const.version, _VERSION )

local BOUNDARY1 = "novus" .. util.rid()
local BOUNDARY2 = "--" .. BOUNDARY1
local BOUNDARY3 = BOUNDARY2 .. "--"

local MULTIPART = ("multipart/form-data;boundary=%s"):format(BOUNDARY1)

local majorRoutes = {
    guilds = true, 
    channels = true, 
    webhooks = true
}

local with_payload = {
    PUT = true,
    PATCH = true,
    POST = true,
}

local mutex_cache = setmetatable({}, 
{
    __mode = "v",
    __index = function (self, k)
        self[k] = util.mutex(k)
        return self[k]
    end
})


local check_anywhere = util.compose(lpeg.check , lpeg.anywhere)
local digits = lpeg.digit^1
local message_endpoint = lpeg.check("/channels" * digits * "/messages/" * digits * -1)
local is_major_route = check_anywhere((lpeg.P"channels" + "guilds" + "webhooks") * "/" * digits * -1)
local ends_in_id = check_anywhere("/" * digits * -1)
local trailing_id = lpeg.anywhere(lpeg.C(lpeg.lazy(1,"/")) * digits * -1)

local function route_of(endpoint, method)
    if method == "DELETE" and message_endpoint:match(endpoint) then 
        return ("%s %s"):format(trailing_id:match(endpoint), method) 
    elseif endpoint:sub(1,9) == "/invites/" then 
        return "/invites/"
    elseif is_major_route:match(endpoint) then 
        return endpoint
    elseif ends_in_id:match(endpoint) then 
        return trailing_id:match(endpoint)
    else 
        return endpoint 
    end
end

local function attachFiles(payload, files) 
	local ret = {
		BOUNDARY2,
		"Content-Disposition:form-data;name=\"payload_json\"",
		"Content-Type:application/json\r\n",
		payload,
	}
	for i, v in ipairs(files) do
		insert(ret, BOUNDARY2)
		insert(ret, ("Content-Disposition:form-data;name=\"file%i\";filename=%q"):format(i, v[1]))
		insert(ret, "Content-Type:application/octet-stream\r\n")
		insert(ret, v[2])
	end
	insert(ret, BOUNDARY3)
	return concat(ret, "\r\n")
end


local token_check = lpeg.check(
	lpeg.S"MN" * lpeg.exactly(58, lpeg.R("09", "az", "AZ") + "-" + "_" + ".") * -1
)

local sample_token = ("X"):rep(59)

function init(t)
    if not (t and t:sub(1,4) == "Bot " and token_check:match(t:sub(5,-1))) then 
        return util.fatal("Please supply a bot token! It should look like \"Bot %s\"",sample_token)
    end
	_ENV.TOKEN  = t
	_ENV.APIID = util.rid()
	util.info("Initialized Api-%s TOKEN-%x", APIID, util.hash(t))
end

function request(method, endpoint, payload, query, files)
    if not cqueues.running() then 
        return util.fatal("Please call REST methods asynchronously.")
    end
	local url = URL .. endpoint
    if query and next(query) then
		url = ("%s?%s"):format(url, httputil.dict_query(query)) 
	end
	local req = newreq.new_from_uri(url)
    req.headers:append(":method", method)
    req.headers:upsert("user-agent", USER_AGENT)
    req.headers:append("authorization", TOKEN)
    if with_payload[method] then 
        payload = payload and json.encode(payload) or '{}'
        if files and next(files) then
			payload = attachFiles(payload, files)
			req.headers:append('content-type', MULTIPART)
		else
			req.headers:append('content-type', JSON)
        end
        req.headers:append("content-length", #payload)
        req:set_body(payload)
    end
	local route = route_of(endpoint, method)
    local routex = mutex_cache[route]
	
    routex:lock()
    local success, data, err, delay = pcall(push, req, ("%s:%s"):format(method,route), 0)
    if not success then 
        return util.fatal("api.push failed %q", tostring(data))
    end
    routex:unlockAfter(delay)

    return not err, data, err
end

function push(req, name, retries)
    local delay = 1 -- seconds
    local headers , stream , errno = req:go(10)
    if not headers and retries < const.max_retries then 
        util.warn("%s failed with (%s, %q) retrying", name, errno[errno], errno.strerror(errno))
        cqueues.sleep(util.rand(1, 2))
        return push(req, name, retries+1)
    end
    local code, rawcode = headers:get":status"
          rawcode, code = code, tonumber(code)

    local date = headers:get"date"
    local reset , remaining = headers:get"x-ratelimit-reset" , headers:get"x-ratelimit-remaining"
    if reset and remaining == '0' then 
        local dt = difftime(reset, Date.parseHeader(date))
        delay = max(dt, delay)
    end
    local raw = stream:get_body_as_string()
    local data = headers:get"content-type" == JSON and json.decode(raw) or raw
    if code < 300 then 
        return data, nil, delay
    else 
        if type(data) == 'table' then 
            local retry;
            if code == 429 then 
                delay = data.retry_after / 1e3
            elseif code == 502 then 
                delay = delay + util.rand(0 , 2)
            end
            retry = retries < 5 
            if retry then 
                util.warn("(%i, %q) :  retrying after %fsec : %s", code, reason[rawcode], delay, name)
                cqueues.sleep(delay)
                return push(req, name, retries+1)
            end
        else
            util.error("(%i, %q) : %s", code, reason[rawcode], name)
            return nil, data, delay
        end
    end
end

-- generated functions

local endpoints = {
	CHANNEL                       = "/channels/%s",
	CHANNEL_INVITES               = "/channels/%s/invites",
	CHANNEL_MESSAGE               = "/channels/%s/messages/%s",
	CHANNEL_MESSAGES              = "/channels/%s/messages",
	CHANNEL_MESSAGES_BULK_DELETE  = "/channels/%s/messages/bulk-delete",
	CHANNEL_MESSAGE_REACTION      = "/channels/%s/messages/%s/reactions/%s",
	CHANNEL_MESSAGE_REACTIONS     = "/channels/%s/messages/%s/reactions",
	CHANNEL_MESSAGE_REACTION_ME   = "/channels/%s/messages/%s/reactions/%s/@me",
	CHANNEL_MESSAGE_REACTION_USER = "/channels/%s/messages/%s/reactions/%s/%s",
	CHANNEL_PERMISSION            = "/channels/%s/permissions/%s",
	CHANNEL_PIN                   = "/channels/%s/pins/%s",
	CHANNEL_PINS                  = "/channels/%s/pins",
	CHANNEL_RECIPIENT             = "/channels/%s/recipients/%s",
	CHANNEL_TYPING                = "/channels/%s/typing",
	CHANNEL_WEBHOOKS              = "/channels/%s/webhooks",
	GATEWAY                       = "/gateway",
	GATEWAY_BOT                   = "/gateway/bot",
	GUILD                         = "/guilds/%s",
	GUILDS                        = "/guilds",
	GUILD_AUDIT_LOGS              = "/guilds/%s/audit-logs",
	GUILD_BAN                     = "/guilds/%s/bans/%s",
	GUILD_BANS                    = "/guilds/%s/bans",
	GUILD_CHANNELS                = "/guilds/%s/channels",
	GUILD_EMBED                   = "/guilds/%s/embed",
	GUILD_EMOJI                   = "/guilds/%s/emojis/%s",
	GUILD_EMOJIS                  = "/guilds/%s/emojis",
	GUILD_INTEGRATION             = "/guilds/%s/integrations/%s",
	GUILD_INTEGRATIONS            = "/guilds/%s/integrations",
	GUILD_INTEGRATION_SYNC        = "/guilds/%s/integrations/%s/sync",
	GUILD_INVITES                 = "/guilds/%s/invites",
	GUILD_MEMBER                  = "/guilds/%s/members/%s",
	GUILD_MEMBERS                 = "/guilds/%s/members",
	GUILD_MEMBERS_ME_NICK         = "/guilds/%s/members/@me/nick",
	GUILD_MEMBER_ROLE             = "/guilds/%s/members/%s/roles/%s",
	GUILD_PRUNE                   = "/guilds/%s/prune",
	GUILD_REGIONS                 = "/guilds/%s/regions",
	GUILD_ROLE                    = "/guilds/%s/roles/%s",
	GUILD_ROLES                   = "/guilds/%s/roles",
	GUILD_VANITY_URL              = "/guilds/%s/vanity-url",
	GUILD_WEBHOOKS                = "/guilds/%s/webhooks",
	INVITE                        = "/invites/%s",
	OAUTH2_APPLICATIONS_ME        = "/oauth2/applications/@me",
	USER                          = "/users/%s",
	USERS_ME                      = "/users/@me",
	USERS_ME_CHANNELS             = "/users/@me/channels",
	USERS_ME_CONNECTIONS          = "/users/@me/connections",
	USERS_ME_GUILD                = "/users/@me/guilds/%s",
	USERS_ME_GUILDS               = "/users/@me/guilds",
	VOICE_REGIONS                 = "/voice/regions",
	WEBHOOK                       = "/webhooks/%s",
	WEBHOOK_TOKEN                 = "/webhooks/%s/%s",
	WEBHOOK_TOKEN_GITHUB          = "/webhooks/%s/%s/github",
	WEBHOOK_TOKEN_SLACK           = "/webhooks/%s/%s/slack",
}

function getGuildAuditLog(guild_id)
	local endpoint = endpoints.GUILD_AUDIT_LOGS:format(guild_id)
	return request("GET", endpoint)
end

function getChannel(channel_id)
	local endpoint = endpoints.CHANNEL:format(channel_id)
	return request("GET", endpoint)
end

function modifyChannel(channel_id, payload)
	local endpoint = endpoints.CHANNEL:format(channel_id)
	return request("PATCH", endpoint, payload)
end

function deleteChannel(channel_id)
	local endpoint = endpoints.CHANNEL:format(channel_id)
	return request("DELETE", endpoint)
end

function getChannelMessages(channel_id)
	local endpoint = endpoints.CHANNEL_MESSAGES:format(channel_id)
	return request("GET", endpoint)
end

function getChannelMessage(channel_id, message_id)
	local endpoint = endpoints.CHANNEL_MESSAGE:format(channel_id, message_id)
	return request("GET", endpoint)
end

function createMessage(channel_id, payload)
	local endpoint = endpoints.CHANNEL_MESSAGES:format(channel_id)
	return request("POST", endpoint, payload)
end

function createReaction(channel_id, message_id, emoji, payload)
	local endpoint = endpoints.CHANNEL_MESSAGE_REACTION_ME:format(channel_id, message_id, emoji)
	return request("PUT", endpoint, payload)
end

function deleteOwnReaction(channel_id, message_id, emoji)
	local endpoint = endpoints.CHANNEL_MESSAGE_REACTION_ME:format(channel_id, message_id, emoji)
	return request("DELETE", endpoint)
end

function deleteUserReaction(channel_id, message_id, emoji, user_id)
	local endpoint = endpoints.CHANNEL_MESSAGE_REACTION_USER:format(channel_id, message_id, emoji, user_id)
	return request("DELETE", endpoint)
end

function getReactions(channel_id, message_id, emoji)
	local endpoint = endpoints.CHANNEL_MESSAGE_REACTION:format(channel_id, message_id, emoji)
	return request("GET", endpoint)
end

function deleteAllReactions(channel_id, message_id)
	local endpoint = endpoints.CHANNEL_MESSAGE_REACTIONS:format(channel_id, message_id)
	return request("DELETE", endpoint)
end

function editMessage(channel_id, message_id, payload)
	local endpoint = endpoints.CHANNEL_MESSAGE:format(channel_id, message_id)
	return request("PATCH", endpoint, payload)
end

function deleteMessage(channel_id, message_id)
	local endpoint = endpoints.CHANNEL_MESSAGE:format(channel_id, message_id)
	return request("DELETE", endpoint)
end

function bulkDeleteMessages(channel_id, payload)
	local endpoint = endpoints.CHANNEL_MESSAGES_BULK_DELETE:format(channel_id)
	return request("POST", endpoint, payload)
end

function editChannelPermissions(channel_id, overwrite_id, payload)
	local endpoint = endpoints.CHANNEL_PERMISSION:format(channel_id, overwrite_id)
	return request("PUT", endpoint, payload)
end

function getChannelInvites(channel_id)
	local endpoint = endpoints.CHANNEL_INVITES:format(channel_id)
	return request("GET", endpoint)
end

function createChannelInvite(channel_id, payload)
	local endpoint = endpoints.CHANNEL_INVITES:format(channel_id)
	return request("POST", endpoint, payload)
end

function deleteChannelPermission(channel_id, overwrite_id)
	local endpoint = endpoints.CHANNEL_PERMISSION:format(channel_id, overwrite_id)
	return request("DELETE", endpoint)
end

function triggerTypingIndicator(channel_id, payload)
	local endpoint = endpoints.CHANNEL_TYPING:format(channel_id)
	return request("POST", endpoint, payload)
end

function getPinnedMessages(channel_id)
	local endpoint = endpoints.CHANNEL_PINS:format(channel_id)
	return request("GET", endpoint)
end

function addPinnedChannelMessage(channel_id, message_id, payload)
	local endpoint = endpoints.CHANNEL_PIN:format(channel_id, message_id)
	return request("PUT", endpoint, payload)
end

function deletePinnedChannelMessage(channel_id, message_id)
	local endpoint = endpoints.CHANNEL_PIN:format(channel_id, message_id)
	return request("DELETE", endpoint)
end

function groupDMAddRecipient(channel_id, user_id, payload)
	local endpoint = endpoints.CHANNEL_RECIPIENT:format(channel_id, user_id)
	return request("PUT", endpoint, payload)
end

function groupDMRemoveRecipient(channel_id, user_id)
	local endpoint = endpoints.CHANNEL_RECIPIENT:format(channel_id, user_id)
	return request("DELETE", endpoint)
end

function listGuildEmojis(guild_id)
	local endpoint = endpoints.GUILD_EMOJIS:format(guild_id)
	return request("GET", endpoint)
end

function getGuildEmoji(guild_id, emoji_id)
	local endpoint = endpoints.GUILD_EMOJI:format(guild_id, emoji_id)
	return request("GET", endpoint)
end

function createGuildEmoji(guild_id, payload)
	local endpoint = endpoints.GUILD_EMOJIS:format(guild_id)
	return request("POST", endpoint, payload)
end

function modifyGuildEmoji(guild_id, emoji_id, payload)
	local endpoint = endpoints.GUILD_EMOJI:format(guild_id, emoji_id)
	return request("PATCH", endpoint, payload)
end

function deleteGuildEmoji(guild_id, emoji_id)
	local endpoint = endpoints.GUILD_EMOJI:format(guild_id, emoji_id)
	return request("DELETE", endpoint)
end

function createGuild(payload)
	local endpoint = endpoints.GUILDS
	return request("POST", endpoint, payload)
end

function getGuild(guild_id)
	local endpoint = endpoints.GUILD:format(guild_id)
	return request("GET", endpoint)
end

function modifyGuild(guild_id, payload)
	local endpoint = endpoints.GUILD:format(guild_id)
	return request("PATCH", endpoint, payload)
end

function deleteGuild(guild_id)
	local endpoint = endpoints.GUILD:format(guild_id)
	return request("DELETE", endpoint)
end

function getGuildChannels(guild_id)
	local endpoint = endpoints.GUILD_CHANNELS:format(guild_id)
	return request("GET", endpoint)
end

function createGuildChannel(guild_id, payload)
	local endpoint = endpoints.GUILD_CHANNELS:format(guild_id)
	return request("POST", endpoint, payload)
end

function modifyGuildChannelPositions(guild_id, payload)
	local endpoint = endpoints.GUILD_CHANNELS:format(guild_id)
	return request("PATCH", endpoint, payload)
end

function getGuildMember(guild_id, user_id)
	local endpoint = endpoints.GUILD_MEMBER:format(guild_id, user_id)
	return request("GET", endpoint)
end

function listGuildMembers(guild_id)
	local endpoint = endpoints.GUILD_MEMBERS:format(guild_id)
	return request("GET", endpoint)
end

function addGuildMember(guild_id, user_id, payload)
	local endpoint = endpoints.GUILD_MEMBER:format(guild_id, user_id)
	return request("PUT", endpoint, payload)
end

function modifyGuildMember(guild_id, user_id, payload)
	local endpoint = endpoints.GUILD_MEMBER:format(guild_id, user_id)
	return request("PATCH", endpoint, payload)
end

function modifyCurrentUserNick(guild_id, payload)
	local endpoint = endpoints.GUILD_MEMBERS_ME_NICK:format(guild_id)
	return request("PATCH", endpoint, payload)
end

function addGuildMemberRole(guild_id, user_id, role_id, payload)
	local endpoint = endpoints.GUILD_MEMBER_ROLE:format(guild_id, user_id, role_id)
	return request("PUT", endpoint, payload)
end

function removeGuildMemberRole(guild_id, user_id, role_id)
	local endpoint = endpoints.GUILD_MEMBER_ROLE:format(guild_id, user_id, role_id)
	return request("DELETE", endpoint)
end

function removeGuildMember(guild_id, user_id)
	local endpoint = endpoints.GUILD_MEMBER:format(guild_id, user_id)
	return request("DELETE", endpoint)
end

function getGuildBans(guild_id)
	local endpoint = endpoints.GUILD_BANS:format(guild_id)
	return request("GET", endpoint)
end

function getGuildBan(guild_id, user_id)
	local endpoint = endpoints.GUILD_BAN:format(guild_id, user_id)
	return request("GET", endpoint)
end

function createGuildBan(guild_id, user_id, payload)
	local endpoint = endpoints.GUILD_BAN:format(guild_id, user_id)
	return request("PUT", endpoint, payload)
end

function removeGuildBan(guild_id, user_id)
	local endpoint = endpoints.GUILD_BAN:format(guild_id, user_id)
	return request("DELETE", endpoint)
end

function getGuildRoles(guild_id)
	local endpoint = endpoints.GUILD_ROLES:format(guild_id)
	return request("GET", endpoint)
end

function createGuildRole(guild_id, payload)
	local endpoint = endpoints.GUILD_ROLES:format(guild_id)
	return request("POST", endpoint, payload)
end

function modifyGuildRolePositions(guild_id, payload)
	local endpoint = endpoints.GUILD_ROLES:format(guild_id)
	return request("PATCH", endpoint, payload)
end

function modifyGuildRole(guild_id, role_id, payload)
	local endpoint = endpoints.GUILD_ROLE:format(guild_id, role_id)
	return request("PATCH", endpoint, payload)
end

function deleteGuildRole(guild_id, role_id)
	local endpoint = endpoints.GUILD_ROLE:format(guild_id, role_id)
	return request("DELETE", endpoint)
end

function getGuildPruneCount(guild_id)
	local endpoint = endpoints.GUILD_PRUNE:format(guild_id)
	return request("GET", endpoint)
end

function beginGuildPrune(guild_id, payload)
	local endpoint = endpoints.GUILD_PRUNE:format(guild_id)
	return request("POST", endpoint, payload)
end

function getGuildVoiceRegions(guild_id)
	local endpoint = endpoints.GUILD_REGIONS:format(guild_id)
	return request("GET", endpoint)
end

function getGuildInvites(guild_id)
	local endpoint = endpoints.GUILD_INVITES:format(guild_id)
	return request("GET", endpoint)
end

function getGuildIntegrations(guild_id)
	local endpoint = endpoints.GUILD_INTEGRATIONS:format(guild_id)
	return request("GET", endpoint)
end

function createGuildIntegration(guild_id, payload)
	local endpoint = endpoints.GUILD_INTEGRATIONS:format(guild_id)
	return request("POST", endpoint, payload)
end

function modifyGuildIntegration(guild_id, integration_id, payload)
	local endpoint = endpoints.GUILD_INTEGRATION:format(guild_id, integration_id)
	return request("PATCH", endpoint, payload)
end

function deleteGuildIntegration(guild_id, integration_id)
	local endpoint = endpoints.GUILD_INTEGRATION:format(guild_id, integration_id)
	return request("DELETE", endpoint)
end

function syncGuildIntegration(guild_id, integration_id, payload)
	local endpoint = endpoints.GUILD_INTEGRATION_SYNC:format(guild_id, integration_id)
	return request("POST", endpoint, payload)
end

function getGuildEmbed(guild_id)
	local endpoint = endpoints.GUILD_EMBED:format(guild_id)
	return request("GET", endpoint)
end

function modifyGuildEmbed(guild_id, payload)
	local endpoint = endpoints.GUILD_EMBED:format(guild_id)
	return request("PATCH", endpoint, payload)
end

function getGuildVanityURL(guild_id)
	local endpoint = endpoints.GUILD_VANITY_URL:format(guild_id)
	return request("GET", endpoint)
end

function getInvite(invite_code)
	local endpoint = endpoints.INVITE:format(invite_code)
	return request("GET", endpoint)
end

function deleteInvite(invite_code)
	local endpoint = endpoints.INVITE:format(invite_code)
	return request("DELETE", endpoint)
end

function getCurrentUser()
	local endpoint = endpoints.USERS_ME
	return request("GET", endpoint)
end

function getUser(user_id)
	local endpoint = endpoints.USER:format(user_id)
	return request("GET", endpoint)
end

function modifyCurrentUser(payload)
	local endpoint = endpoints.USERS_ME
	return request("PATCH", endpoint, payload)
end

function getCurrentUserGuilds()
	local endpoint = endpoints.USERS_ME_GUILDS
	return request("GET", endpoint)
end

function leaveGuild(guild_id)
	local endpoint = endpoints.USERS_ME_GUILD:format(guild_id)
	return request("DELETE", endpoint)
end

function getUserDMs()
	local endpoint = endpoints.USERS_ME_CHANNELS
	return request("GET", endpoint)
end

function createDM(payload)
	local endpoint = endpoints.USERS_ME_CHANNELS
	return request("POST", endpoint, payload)
end

function createGroupDM(payload)
	local endpoint = endpoints.USERS_ME_CHANNELS
	return request("POST", endpoint, payload)
end

function getUserConnections()
	local endpoint = endpoints.USERS_ME_CONNECTIONS
	return request("GET", endpoint)
end

function listVoiceRegions()
	local endpoint = endpoints.VOICE_REGIONS
	return request("GET", endpoint)
end

function createWebhook(channel_id, payload)
	local endpoint = endpoints.CHANNEL_WEBHOOKS:format(channel_id)
	return request("POST", endpoint, payload)
end

function getChannelWebhooks(channel_id)
	local endpoint = endpoints.CHANNEL_WEBHOOKS:format(channel_id)
	return request("GET", endpoint)
end

function getGuildWebhooks(guild_id)
	local endpoint = endpoints.GUILD_WEBHOOKS:format(guild_id)
	return request("GET", endpoint)
end

function getWebhook(webhook_id)
	local endpoint = endpoints.WEBHOOK:format(webhook_id)
	return request("GET", endpoint)
end

function getWebhookWithToken(webhook_id, webhook_token)
	local endpoint = endpoints.WEBHOOK_TOKEN:format(webhook_id, webhook_token)
	return request("GET", endpoint)
end

function modifyWebhook(webhook_id, payload)
	local endpoint = endpoints.WEBHOOK:format(webhook_id)
	return request("PATCH", endpoint, payload)
end

function modifyWebhookWithToken(webhook_id, webhook_token, payload)
	local endpoint = endpoints.WEBHOOK_TOKEN:format(webhook_id, webhook_token)
	return request("PATCH", endpoint, payload)
end

function deleteWebhook(webhook_id)
	local endpoint = endpoints.WEBHOOK:format(webhook_id)
	return request("DELETE", endpoint)
end

function deleteWebhookWithToken(webhook_id, webhook_token)
	local endpoint = endpoints.WEBHOOK_TOKEN:format(webhook_id, webhook_token)
	return request("DELETE", endpoint)
end

function executeWebhook(webhook_id, webhook_token, payload)
	local endpoint = endpoints.WEBHOOK_TOKEN:format(webhook_id, webhook_token)
	return request("POST", endpoint, payload)
end

function executeSlackCompatibleWebhook(webhook_id, webhook_token, payload)
	local endpoint = endpoints.WEBHOOK_TOKEN_SLACK:format(webhook_id, webhook_token)
	return request("POST", endpoint, payload)
end

function executeGitHubCompatibleWebhook(webhook_id, webhook_token, payload)
	local endpoint = endpoints.WEBHOOK_TOKEN_GITHUB:format(webhook_id, webhook_token)
	return request("POST", endpoint, payload)
end

function getGateway()
	local endpoint = endpoints.GATEWAY
	return request("GET", endpoint)
end

function getGatewayBot()
	local endpoint = endpoints.GATEWAY_BOT
	return request("GET", endpoint)
end

function getCurrentApplicationInformation()
	local endpoint = endpoints.OAUTH2_APPLICATIONS_ME
	return request("GET", endpoint)
end

--end-module--
return _ENV