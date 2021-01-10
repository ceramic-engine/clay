package clay;

#if clay_web
typedef Assets = clay.web.WebAssets;
#elseif clay_native
typedef Assets = clay.native.NativeAssets;
#end
