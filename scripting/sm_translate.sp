#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <system2>
#include <ripext>
#include <multicolors>
#include <log>
#include <clientprefs>

ConVar cvarTranslatePath;
char g_translatePath[64];

Cookie langOverride;

/**
 * TODO: 
 *  [ ] admin chat support
 * FIX: responses are per player count
 */

public Plugin myinfo = {
    name =  "Translate Chat Messages", 
    author = "jackzmc", 
    description = "", 
    version = "1.0", 
    url = "https://github.com/Jackzmc/sm-translate"
};

public void OnPluginStart() {
    cvarTranslatePath = CreateConVar("sm_translate_api_path", "http://localhost:5000/translate", "The full protocol + host + path to the translation endpoint");
    cvarTranslatePath.AddChangeHook(OnPathChanged);
    cvarTranslatePath.GetString(g_translatePath, sizeof(g_translatePath));

    Log_Init("translate", Log_Info, ADMFLAG_GENERIC);

    langOverride = new Cookie("translate_target", "Desired language (code) for messages to translate to", CookieAccess_Public);

    RegConsoleCmd("sm_t", Command_Translate, "Manually translate sentence to desired language");

    RegConsoleCmd("sm_lang", Command_SetLanguage, "Set your target language");

    AutoExecConfig(true, "sm_translate");

}

void OnPathChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
    strcopy(g_translatePath, sizeof(g_translatePath), newValue);
}

/////////// TRIGGERS

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs) {
    if(client > 0 && StrEqual(command, "say") && !IsFakeClient(client) && g_translatePath[0] != '\0') {
        CheckTranslate(client, sArgs, null);
    }
}

Action Command_SetLanguage(int client, int args) {
    char arg[8];
    if(args == 0) {
        GetCmdArg(0, arg, sizeof(arg));
        ReplyToCommand(client, "Syntax: %s <language code>", arg);
        ReplyToCommand(client, "See your console for list of languages. Code is in brackets.");
        int result = GetClientLanguageCode(client, arg, sizeof(arg));
        if(result == -1) {
            ReplyToCommand(client, "Translations currently disabled for you");
        } else if(result == 0) {
            ReplyToCommand(client, "Current language: \"%s\" (game)", arg);
        } else {
            ReplyToCommand(client, "Current language: \"%s\" (override)", arg);
        }

        int numLangs = GetLanguageCount();
        char name[32];
        PrintToConsole(client, "\"DEFAULT\" to use game language, and \"OFF\" to disable");
        for(int i = 0; i < numLangs; i++) {
            GetLanguageInfo(i, arg, sizeof(arg), name, sizeof(name));
            PrintToConsole(client, "#%d. [%s] %s", i, arg, name);
        }
        return Plugin_Handled;
    }
    GetCmdArg(1, arg, sizeof(arg));

    if(StrEqual(arg, "OFF")) {
        langOverride.Set(client, "_OFF_");
        ReplyToCommand(client, "Translations disabled. You will not see any translations");
        return Plugin_Handled;
    } else if(StrEqual(arg, "DEFAULT")) {
        langOverride.Set(client, "");
        ReplyToCommand(client, "Language preference set to use game language");
        return Plugin_Handled;
    }

    int langId = GetLanguageByCode(arg);
    if(langId == -1) {
        ReplyToCommand(client, "Unknown language code");
        return Plugin_Handled;
    }
    langOverride.Set(client, arg);
    ReplyToCommand(client, "Language preference set to #%d [%s]", langId, arg);
    return Plugin_Handled;
}

Action Command_Translate(int client, int args) {
    if(args < 2) {
        char arg[4];
        GetCmdArg(0, arg, sizeof(arg));
        ReplyToCommand(client, "Syntax: %s LANG \"message in quotes\"", arg);
        return Plugin_Handled;
    }

    char code[4];
    GetCmdArg(1, code, sizeof(code));
    char msg[256];
    GetCmdArg(2, msg, sizeof(msg));

    MergeRemainingArgs(3, msg, sizeof(msg));

    ArrayList targets = new ArrayList();
    targets.PushString(code);

    CheckTranslate(client, msg, targets);

    return Plugin_Handled;
}

ArrayList GetTargetLanguages() {
    ArrayList list = new ArrayList();
    char code[8];
    int serverId = GetServerLanguage();
    GetLanguageInfo(serverId, code, sizeof(code), "", 0);

    for(int i = 1; i <= MaxClients; i++) {
        if(IsClientInGame(i) && !IsFakeClient(i)) {
            if(GetClientLanguageCode(i, code, sizeof(code)) == -1) {
                continue;
            }
            
            if(list.FindString(code) == -1) {
                list.PushString(code);
            }
        }
    }
    return list;
}

/***
 * Attempts to automatically translate message into desired languages
 * @param client client user index that sent message
 * @param message message to translate
 * @param desiredLanguages a list of language code strings to translate. if null, will be populated with all online players' languages
 * @param skipCheck if true, skips the language check optimization and translates always
 */
void CheckTranslate(int client, const char[] message, ArrayList desiredLanguages = null) {
    if(desiredLanguages == null) desiredLanguages = GetTargetLanguages();

    int msgLen = strlen(message) * 2; 
    char[] msg = new char[msgLen];
    System2_URLEncode(msg, msgLen, "%s", message);

    char targets[32];
    JoinString(desiredLanguages, 4, targets, sizeof(targets));
    System2_URLEncode(targets, sizeof(targets), "%s", targets);
    delete desiredLanguages;

    static char buffer[256];
    Format(buffer, sizeof(buffer), "?text=%s&targets=%s", msg, targets);

    LogDebug("query %s", buffer);

    System2HTTPRequest request = new System2HTTPRequest(OnTranslateResponse, "%s%s", g_translatePath, buffer);
    request.Any = GetClientUserId(client);
    request.POST();
}

void OnTranslateResponse(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method) {
    if(!response) {
        LogError("Network error %s", error);
        return;
    } else if (response.StatusCode != 200) {
        LogError("Translate failed. Status %d", response.StatusCode);
        return;
    }

    char buffer[256];
    response.GetContent(buffer, sizeof(buffer));
    JSONObject obj = JSONObject.FromString(buffer);
    char srcLang[8];
    // Not detected
    if(obj.IsNull("source")) return;

    obj.GetString("source", srcLang, sizeof(srcLang));

    JSONArray translations = view_as<JSONArray>(obj.Get("translations"));
    JSONObject result;

    LogDebug("source=%s translations=%d uid=%d", srcLang, translations.Length, request.Any);
    char lang[8];
    int client = GetClientOfUserId(request.Any);
    for(int i = 0; i < translations.Length; i++) {
        result = view_as<JSONObject>(translations.Get(i));
        result.GetString("lang", lang, sizeof(lang));
        result.GetString("text", buffer, sizeof(buffer));

        SendTranslation(client, srcLang, lang, buffer);
    }
}

bool SendTranslation(int sourceClient, const char[] srcLangCode, const char[] targetLangCode, const char[] msg) {
    char code[8];
    for(int i = 1; i <= MaxClients; i++) {
        if(IsClientInGame(i) && !IsFakeClient(i)) {
            if(GetClientLanguageCode(i, code, sizeof(code)) == -1) {
                continue;
            }
            if(StrEqual(targetLangCode, code)) {
                C_PrintToChat(i, "{olive}[%s] %N: %s", srcLangCode, sourceClient, msg);
            }
        }
    }

    LogInfo("TRANS [%s] %N: %s", srcLangCode, sourceClient, msg);

    return true;
}

////////// UTILS

void JoinString(ArrayList list, int partMaxLength, char[] output, int maxlen) {
    char[] buffer = new char[partMaxLength];
    for(int i = 0; i < list.Length; i++) {
        list.GetString(i, buffer, partMaxLength);
        Format(output, maxlen, "%s%s%s", output, buffer, (i != list.Length - 1 ? "," : ""));
    }
}

void MergeRemainingArgs(int argIndex, char[] output, int maxlen) {
    // Correct commands that don't wrap message in quotes
    int args = GetCmdArgs();
    if(args > argIndex) {
        char buffer[64];
        for(int i = argIndex; i <= args; i++) {
            GetCmdArg(i, buffer, sizeof(buffer));
            Format(output, maxlen, "%s %s", output, buffer);
        }
    }
}


/**
 * Get clients language code. Returns 0 if game language, 1 if override, -1 if disabled
 */
int GetClientLanguageCode(int client, char[] code, int maxlen) {
    langOverride.Get(client, code, maxlen);
    if(code[0] == '\0') {
        int langId = GetClientLanguage(client);
        GetLanguageInfo(langId, code, maxlen, "", 0);
        return 0;
    } else if(StrEqual(code, "_OFF_")) {
        return -1;
    }
    return 1;
}
