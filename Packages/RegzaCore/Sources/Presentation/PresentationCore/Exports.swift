// 画面の状態と操作の型が使う UI の型 (SharedModels) を、プレゼンテーション層を読み込んだ側にも見せる。
// Domain の型は見せない (各ファイルの RegzaDomain は package import なので、同じパッケージの組み立てにだけ見える)
@_exported public import RegzaSharedModels
