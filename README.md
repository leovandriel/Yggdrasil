Yggdrasil
===========

*Objective-C quadtree implementation with OS X visualization app.*


About
-----
Yggdrasil turns a simple 2D mapping into a quad tree by recursively sampling coordinates. It can be used for generating a fast lookup for country codes based on a slow lookups like polygon intersection or even web requests.

![Screenshot countries of the world](Yggdrasil/raw/master/Demo/screenshot.png)


Labeler
-------
Yggdrasil builds up its quadtree by sampling labels from a *labeler*. A labeler provides a mapping from 2D coordinates to string labels. All labelers implement the `YGLabeler` protocol, which includes the method:

    - (void)labelAtPoint:(NSPoint)point block:(void (^)(NSString *))block;

The `NSPoint` parameter is contained in the rectangle returned by `- (NSRect)rect`. The callback block allows for asynchronous lookup, for example to fetch labels from a web server.


Caching
-------
All sampled labels are stored in cache file to allow fast reruns of the same labeler. This cache is stored in `~/Caches/Yggdrasil` with a `.cache` extension, which is JSON data. 

When the labeling completes, the quadtree is stored in the same folder with a `.ygg` extension. The format of this file is derived from the JSON format, and contains nested arrays with four elements. Each array represents a tree node and can contain both sub-arrays and labels. The tree leafs are string labels.

Element are ordered left to right, bottom to top. For example:

    +-------+-------+
    | C | D |       |
    +---+---+       |
    | B |   |       |
    +-------+-------+
    |       |       |
    |       |   A   |
    |       |       |
    +-------+-------+

is encoded as:

    [,A,[B,,C,D],]
    

Lookup
------
Demo Ruby code is included to demonstrate the lookup process in a generated quadtree:

    ruby lookup.rb 52 5


Geodata
-------
The `YGGeoJsonLabeler` class relies on the file `world.json`, which is included in this project. This file contains [GeoJSON](http://www.geojson.org/geojson-spec.html) data that was downloaded from [github.com/johan/world.geo.json](https://github.com/johan/world.geo.json).

More geo data can be found here:

* [www.diva-gis.org](http://www.diva-gis.org/Data)
* [www.gadm.org](http://www.gadm.org/)
* [www.unsalb.org](http://www.unsalb.org/)
* [www.thematicmapping.org](http://thematicmapping.org/downloads/world_borders.php)
* [www.mappinghacks.com](http://www.mappinghacks.com/data/)

Use [GDAL](http://www.gdal.org/) to convert formats. On OS X this can be installed with [Homebrew](http://mxcl.github.com/homebrew/). Example usage:

    ogr2ogr -f GeoJSON world.json world.shp


License
-------
Yggdrasil is licensed under the terms of the BSD 2-Clause License, see the included LICENSE file.


Authors
-------
- [Leonard van Driel](http://www.leonardvandriel.nl/)
