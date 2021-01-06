package clay;

#if ceramic
typedef IntMap<T> = ceramic.IntMap<T>;
#else
typedef IntMap<T> = haxe.ds.IntMap<T>;
#end
