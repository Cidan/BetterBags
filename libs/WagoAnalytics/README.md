In your plugin's `.pkgmeta` file, add the following:

```
externals:
  libs/WagoAnalyticsShim:
    url: https://github.com/wagoio/WagoAnalyticsShim.git
    branch: main
```

And in your `.toc` file, add the following:
```
## OptionalDependencies: WagoAnalytics

libs\WagoAnalyticsShim\Shim.lua
```
