package clay;

#if clay_web
typedef Audio = clay.web.WebAudio;
#elseif (clay_native && clay_openal)
typedef Audio = clay.openal.OpenALAudio;
#elseif (clay_native && clay_soloud)
typedef Audio = clay.soloud.SoloudAudio;
#end
