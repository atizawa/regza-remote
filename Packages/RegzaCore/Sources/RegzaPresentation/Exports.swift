// iOS・Android・CLI が import RegzaPresentation だけで、ViewModel と UI の型 (SharedModels) を使えるようにする。
// Domain の型は見せない (各ファイルの RegzaDomain は package import なので、同じパッケージの組み立てにだけ見える)
@_exported public import RegzaSharedModels
