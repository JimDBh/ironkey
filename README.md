# ironkey

This package provides functions to protect certain key-bindings in certain
keymaps. It mainly does this in two ways when ironkey-mode is enabled:

* For each `(key . map)` pair in `ironkey-iron-alist`, if there's an attempt to
  bind `key` in `map` to a different value, ironkey will not perform such binding.
  When `map` is nil, ironkey protects `key` in `global-map`.

* To avoid clashing among minor mode maps, the local map and the global map, ironkey
  will also, for each of the `(key . map)` pairs, force the binding of `key` in `map`
  to have higher priority when `map` is active in the current buffer.  This is
  done by the `ironkey-update` function, which can also be called manually to
  refresh the status.

## Installation

This package is not on Melpa, so the best ways would be to use
[straight.el](https://github.com/raxod502/straight.el) or
[quelpa.el](https://github.com/quelpa/quelpa).

Alternatively one could download the files to one's load path and `require 'ironkey`.

Example using `straight` and `use-package`:

```lisp
(use-package ironkey
  :straight (:type git :host github :repo "JimDBh/ironkey")
  :demand t
  :hook ((after-init . ironkey-update))
  :config
  (setq ironkey-iron-alist `((,(kbd "M-.") . nil) ;; command in global-map
                             (,(kbd "C-x p") . nil) ;; prefix keymap in global-map
                             (,(kbd "<tab>") . company-mode))) ;; command in minor mode map
  (ironkey-mode t))
```

## Usage

The custom variable `ironkey-iron-alist` should be set as an alist of `(key . map)`
pairs. Note `key` should be an internal representation of the key
combo, which can usually be obtained by the `kbd` function. For example:

```lisp
(setq ironkey-iron-alist `((,(kbd "M-.") . nil)
                           (,(kbd "<tab>") . company-mode-map)))
```

Next just simply turn on the global `ironkey-mode`.

Currently there are no way to force set a protected key binding. Therefore if
one needs to update a protected key's binding, please temporarily turn off
`ironkey-mode` and then turn it on again afterwards.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for details.

## License

Apache 2.0; see [`LICENSE`](LICENSE) for details.

## Disclaimer

This project is not an official Google project. It is not supported by
Google and Google specifically disclaims all warranties as to its quality,
merchantability, or fitness for a particular purpose.
