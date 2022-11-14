# Block Safari

このコントラクトコードによって、
ANIMALS,PARKS,ITEMS(provisional)の３つのコントラクトがデプロイされます。

contracts/upgradeable/Sale.sol をデプロイし、
そのコントラクトアドレスをcontracts/BlockSafari.solの第一引数に指定してデプロイします。
それぞれのロジックコードにバグが発生した場合は、Sale.solを修正したコントラクトをデプロイして、
BlockSafariコントラクトでupdateToメソッドを使用してロジックコントラクトを置換します。
