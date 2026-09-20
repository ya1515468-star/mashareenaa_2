import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS"};

Deno.serve(async(req:Request)=>{
  if(req.method==="OPTIONS") return new Response("ok",{headers:cors});
  try{
    const auth=req.headers.get("Authorization")??"";
    const token=auth.startsWith("Bearer ")?auth.slice(7):"";
    if(!token) throw new Error("AUTH_REQUIRED");
    const url=Deno.env.get("SUPABASE_URL")!;
    const serviceKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const admin=createClient(url,serviceKey);
    const {data:userData,error:userError}=await admin.auth.getUser(token);
    if(userError||!userData.user) throw new Error("AUTH_REQUIRED");
    const uid=userData.user.id;
    const body=await req.json();
    const kind=String(body.kind??"");
    const variant=String(body.variant??"video");
    const id=String(body.id??"");
    const purpose=String(body.purpose??"play");
    let path="";
    let downloadName="mashareena-media";

    if(kind==="reel"){
      const {data:reel,error}=await admin.from("producer_reels").select("id,owner_uid,video_url,thumbnail_url,is_published,is_blocked,allow_download,title").eq("id",id).maybeSingle();
      if(error||!reel) throw new Error("REEL_NOT_FOUND");
      const publicVisible=reel.is_published===true&&reel.is_blocked!==true;
      const owner=reel.owner_uid===uid;
      let isOwner=false;
      if(!publicVisible&&!owner){
        const {data:ownerResult,error:ownerError}=await admin.rpc("_is_platform_owner",{p_uid:uid});
        if(ownerError) throw new Error("OWNER_CHECK_FAILED");
        isOwner=ownerResult===true;
      }
      if(!publicVisible&&!owner&&!isOwner) throw new Error("FORBIDDEN");
      if(purpose==="download"&&!owner&&!isOwner&&reel.allow_download!==true) throw new Error("DOWNLOAD_DISABLED");
      path=variant==="thumbnail"?String(reel.thumbnail_url??""):String(reel.video_url??"");
      if(path.startsWith("storage://")){
        const prefix="storage://producer-market-media/reels/"+String(reel.owner_uid)+"/";
        if(!path.startsWith(prefix)) throw new Error("INVALID_REEL_MEDIA_PATH");
        const rawObject=path.slice("storage://".length);
        const slash=rawObject.indexOf("/");
        if(slash<=0||rawObject.slice(0,slash)!=="producer-market-media") throw new Error("INVALID_REEL_MEDIA_PATH");
        const objectPath=rawObject.slice(slash+1);
        if(!objectPath.startsWith("reels/"+String(reel.owner_uid)+"/")) throw new Error("INVALID_REEL_MEDIA_PATH");
      }
      const safeTitle=String(reel.title??"mashareena-reel").replaceAll(/[^a-zA-Z0-9-_]+/g,"_");
      downloadName=safeTitle+(variant==="thumbnail"?".jpg":".mp4");
    }

    if(kind==="season"){
      const {data:season,error}=await admin.from("producers_market_season").select("is_active,background_url,overlay_gif_url").eq("id",true).maybeSingle();
      if(error||!season||season.is_active!==true) throw new Error("SEASON_DISABLED");
      path=variant==="overlay"?String(season.overlay_gif_url??""):String(season.background_url??"");
      if(path&&!path.startsWith("storage://producer-market-media/season/")) throw new Error("INVALID_SEASON_MEDIA_PATH");
      downloadName=variant==="overlay"?"season-effect.gif":"season-background";
    }

    if(kind==="storage"){
      path=String(body.path??"");
      if(!path.startsWith("storage://")) throw new Error("INVALID_STORAGE_PATH");
      const raw=path.slice("storage://".length);
      const slash=raw.indexOf("/");
      if(slash<=0) throw new Error("INVALID_STORAGE_PATH");
      const bucket=raw.slice(0,slash);
      const objectPath=raw.slice(slash+1);
      const parts=objectPath.split("/");
      const section=parts[0]??"";
      const pathUid=parts[1]??"";
      const {data:isOwner}=await admin.rpc("_is_platform_owner",{p_uid:uid});
      let allowed=isOwner===true||((section==="reels"||section==="tenders")&&pathUid===uid);
      if(!allowed&&section==="tenders"){
        const {data:visible}=await admin.from("tenders").select("id").neq("status","draft").neq("is_blocked",true).contains("attachments",[path]).limit(1).maybeSingle();
        allowed=!!visible;
      }
      if(!allowed||bucket!=="producer-market-media") throw new Error("FORBIDDEN");
      downloadName=String(body.filename??parts[parts.length-1]??"mashareena-media");
    }

    if(!path) throw new Error("MEDIA_NOT_FOUND");
    if(!path.startsWith("storage://")) return new Response(JSON.stringify({ok:true,url:path,direct:true}),{status:200,headers:{...cors,"content-type":"application/json"}});

    const raw=path.slice("storage://".length);
    const slash=raw.indexOf("/");
    if(slash<=0) throw new Error("INVALID_STORAGE_PATH");
    const bucket=raw.slice(0,slash);
    const objectPath=raw.slice(slash+1);
    if(bucket!=="producer-market-media") throw new Error("FORBIDDEN");
    if(kind==="season"&&!objectPath.startsWith("season/")) throw new Error("INVALID_SEASON_MEDIA_PATH");
    if(kind==="reel"&&!objectPath.startsWith("reels/")) throw new Error("INVALID_REEL_MEDIA_PATH");

    const ttl=purpose==="download"?600:180;
    const {data:signed,error:signError}=await admin.storage.from(bucket).createSignedUrl(objectPath,ttl);
    if(signError||!signed?.signedUrl) throw new Error("SIGNED_URL_FAILED");
    let signedUrl=signed.signedUrl;
    if(purpose==="download") signedUrl+=(signedUrl.includes("?")?"&":"?")+"download="+encodeURIComponent(downloadName);
    return new Response(JSON.stringify({ok:true,url:signedUrl,direct:false}),{status:200,headers:{...cors,"content-type":"application/json"}});
  }catch(error){
    const message=error instanceof Error?error.message:"MEDIA_URL_FAILED";
    const status=message==="FORBIDDEN"||message==="DOWNLOAD_DISABLED"?403:message==="AUTH_REQUIRED"?401:400;
    return new Response(JSON.stringify({ok:false,error:message}),{status,headers:{...cors,"content-type":"application/json"}});
  }
});
