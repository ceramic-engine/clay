package clay;

#if clay_web
typedef Audio = clay.web.WebAudio;
#elseif clay_native
typedef Audio = clay.openal.OpenALAudio;
#end
