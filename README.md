# elm-css-extractor

## Motivation

This project is in an early prototype stage. The main goal is to improve performance by:

- Reducing JS bundle size
- Moving some work to the build step instead of runtime
- Performing some build-time optimizations (for example, when collecting styles there may be opportunities to share some common CSS between classes)

`elm-css` (and CSS-in-JS tools in general) adds performance overhead.

- Runtime overhead to collect and hash styles
- Additional JS parsing time (which is more expensive than parsing stylesheets)

CSS is a more constrained language, and we can do some precomputation to optimize things even further if we extract styles to a plain CSS file.

A concrete example of real-world performance problems, this comment has a video that shows recomputation of styles taking about 3 seconds for a page with about 900 elements with about 20 styles each:

https://github.com/rtfeldman/elm-css/pull/584#issue-1359649403

This seems within a normal range that seems fair to expect to run smoothly (not on the order of seconds) without manually applying `keyed` or `lazy`. Imagine that same example as a CSS file with a class that is applied to each of those 900 nodes and how the performance would be there. I'd like to collect more data to compare the results concretely. This kind of issue is the motivating use case.

CSS and JS parsing can also be done in parallel, whereas computing styles in JS means that work needs to be done after all the JS has been parsed and then additional work is needed to compute styles: https://twitter.com/slightlylate/status/1517173353869561857.
