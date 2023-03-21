import 'package:budget/database/tables.dart';
import 'package:budget/main.dart';
import 'package:budget/pages/addTransactionPage.dart';
import 'package:budget/pages/editWalletsPage.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/widgets/accountAndBackup.dart';
import 'package:budget/widgets/openBottomSheet.dart';
import 'package:budget/widgets/openPopup.dart';
import 'package:budget/widgets/pageFramework.dart';
import 'package:budget/widgets/popupFramework.dart';
import 'package:budget/widgets/saveBottomButton.dart';
import 'package:budget/widgets/selectColor.dart';
import 'package:budget/widgets/tappable.dart';
import 'package:budget/widgets/textInput.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:budget/colors.dart';

class AddWalletPage extends StatefulWidget {
  AddWalletPage({
    Key? key,
    required this.title,
    this.wallet,
  }) : super(key: key);
  final String title;

  //When a wallet is passed in, we are editing that wallet
  final TransactionWallet? wallet;

  @override
  _AddWalletPageState createState() => _AddWalletPageState();
}

class _AddWalletPageState extends State<AddWalletPage> {
  bool? canAddWallet;

  String? selectedTitle;
  Color? selectedColor;
  String? selectedIconName;
  Map<String, dynamic> currencies = {};
  bool customCurrencyIcon = false;
  String? searchCurrency = "";
  String selectedCurrency = "";

  late FocusNode _periodLengthFocusNode;

  String? textAddWallet = "Add Wallet";

  Future<void> selectColor(BuildContext context) async {
    openBottomSheet(
      context,
      PopupFramework(
        title: "Select Color",
        child: SelectColor(
          selectedColor: selectedColor,
          setSelectedColor: setSelectedColor,
        ),
      ),
    );
  }

  Future<void> selectTitle() async {
    openBottomSheet(
      context,
      PopupFramework(
        title: "Enter Name",
        child: SelectText(
          setSelectedText: setSelectedTitle,
          labelText: "Name",
          selectedText: selectedTitle,
        ),
      ),
      snap: false,
    );
  }

  void setSelectedTitle(String title) {
    setState(() {
      selectedTitle = title;
    });
    determineBottomButton();
    return;
  }

  void setSelectedColor(Color? color) {
    selectedColor = color;
    determineBottomButton();
    return;
  }

  void setSelectedCurrency(String currencyKey) {
    setState(() {
      selectedCurrency = currencyKey;
    });
    determineBottomButton();
    return;
  }

  void setSelectedIconName(String iconName) {
    setState(() {
      selectedIconName = iconName;
    });
    return;
  }

  Future addWallet() async {
    print("Added wallet");
    await database.createOrUpdateWallet(await createTransactionWallet());
    Navigator.pop(context);
  }

  Future<TransactionWallet> createTransactionWallet() async {
    int numberOfWallets = (await database.getTotalCountOfWallets())[0] ?? 0;
    return TransactionWallet(
      walletPk: widget.wallet != null
          ? widget.wallet!.walletPk
          : DateTime.now().millisecondsSinceEpoch,
      name: selectedTitle ?? "",
      colour: toHexString(selectedColor),
      dateCreated:
          widget.wallet != null ? widget.wallet!.dateCreated : DateTime.now(),
      dateTimeModified: null,
      order: widget.wallet != null ? widget.wallet!.order : numberOfWallets,
      currency: selectedCurrency,
    );
  }

  void populateCurrencies() {
    Future.delayed(Duration.zero, () async {
      setState(() {
        //Set to false because we can't save until we made some changes
        canAddWallet = false;
        currencies = currenciesJSON;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _periodLengthFocusNode = FocusNode();

    if (widget.wallet != null) {
      //We are editing a wallet
      textAddWallet = "Edit Wallet";
      //Fill in the information from the passed in wallet
      //Outside of future.delayed because of textinput when in web mode initial value
      selectedTitle = widget.wallet!.name;
      selectedColor = widget.wallet!.colour == null
          ? null
          : HexColor(widget.wallet!.colour);
      selectedCurrency = widget.wallet!.currency ?? "usd";
    } else {}
    populateCurrencies();
  }

  @override
  void dispose() {
    _periodLengthFocusNode.dispose();
    super.dispose();
  }

  determineBottomButton() {
    if (selectedTitle != null && selectedCurrency != "") {
      if (canAddWallet != true)
        this.setState(() {
          canAddWallet = true;
        });
    } else {
      if (canAddWallet != false)
        this.setState(() {
          canAddWallet = false;
        });
    }
  }

  void searchCurrencies(String searchTerm) async {
    if (searchTerm == "") {
      populateCurrencies();
    } else {
      Map<String, dynamic> outCurrencies = {};
      for (String key in currenciesJSON.keys) {
        dynamic currency = currenciesJSON[key];
        if ((currency["CountryName"] != null &&
                currency["CountryName"]
                    .toLowerCase()
                    .contains(searchTerm.toLowerCase())) ||
            (currency["Currency"] != null &&
                currency["Currency"]
                    .toLowerCase()
                    .contains(searchTerm.toLowerCase())) ||
            (currency["Code"] != null &&
                currency["Code"]
                    .toLowerCase()
                    .contains(searchTerm.toLowerCase()))) {
          outCurrencies[key] = currency;
        }
      }
      setState(() {
        currencies = outCurrencies;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (widget.wallet != null) {
          discardChangesPopup(
            context,
            previousObject: widget.wallet,
            currentObject: await createTransactionWallet(),
          );
        } else {
          discardChangesPopup(context);
        }
        return false;
      },
      child: GestureDetector(
        onTap: () {
          //Minimize keyboard when tap non interactive widget
          FocusScopeNode currentFocus = FocusScope.of(context);
          if (!currentFocus.hasPrimaryFocus) {
            currentFocus.unfocus();
          }
        },
        child: PageFramework(
          resizeToAvoidBottomInset: true,
          dragDownToDismiss: true,
          title: widget.title,
          navbar: false,
          onBackButton: () async {
            if (widget.wallet != null) {
              discardChangesPopup(
                context,
                previousObject: widget.wallet,
                currentObject: await createTransactionWallet(),
              );
            } else {
              discardChangesPopup(context);
            }
          },
          onDragDownToDissmiss: () async {
            if (widget.wallet != null) {
              discardChangesPopup(
                context,
                previousObject: widget.wallet,
                currentObject: await createTransactionWallet(),
              );
            } else {
              discardChangesPopup(context);
            }
          },
          actions: [
            widget.wallet != null && widget.wallet!.walletPk != 0
                ? IconButton(
                    tooltip: "Delete wallet",
                    onPressed: () {
                      deleteWalletPopup(context, widget.wallet!,
                          afterDelete: () {
                        Navigator.pop(context);
                      });
                    },
                    icon: Icon(Icons.delete_rounded),
                  )
                : SizedBox.shrink()
          ],
          overlay: Align(
            alignment: Alignment.bottomCenter,
            child: SaveBottomButton(
              label: widget.wallet == null ? "Add Wallet" : "Save Changes",
              onTap: () async {
                await addWallet();
                createSyncBackup(changeMadeSync: true);
              },
              disabled: !(canAddWallet ?? false),
            ),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextInput(
                  labelText: "Name",
                  bubbly: false,
                  initialValue: selectedTitle,
                  onChanged: (text) {
                    setSelectedTitle(text);
                  },
                  padding: EdgeInsets.only(left: 7, right: 7),
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  topContentPadding: 20,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: 14),
            ),
            SliverToBoxAdapter(
              child: Container(
                height: 65,
                child: SelectColor(
                  horizontalList: true,
                  selectedColor: selectedColor,
                  setSelectedColor: setSelectedColor,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: 15),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextFont(
                  text: "Select Currency",
                  textColor: Theme.of(context).colorScheme.textLight,
                  fontSize: 16,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: 10),
            ),
            SliverToBoxAdapter(
              child: TextInput(
                labelText: "Search currencies...",
                icon: Icons.search_rounded,
                onChanged: (text) {
                  searchCurrencies(text);
                },
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: 15),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  String key = currencies.keys.toList()[index];
                  return Padding(
                    padding:
                        const EdgeInsets.only(left: 18.0, right: 18, bottom: 5),
                    child: Tappable(
                      color: selectedCurrency == key
                          ? Theme.of(context).colorScheme.secondaryContainer
                          : Theme.of(context).colorScheme.lightDarkAccent,
                      borderRadius: 13,
                      onTap: () {
                        FocusScopeNode currentFocus = FocusScope.of(context);
                        if (!currentFocus.hasPrimaryFocus) {
                          currentFocus.unfocus();
                        }
                        setSelectedCurrency(key);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 17, vertical: 10),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            IntrinsicWidth(
                              child: Row(
                                children: [
                                  TextFont(
                                      text: currencies[key]?["CountryName"] ??
                                          currencies[key]?["Currency"]),
                                ],
                              ),
                            ),
                            IntrinsicWidth(
                              child: Row(
                                children: [
                                  Text(
                                    currencies[key]["Symbol"],
                                    style: TextStyle(
                                      fontSize: 18,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  TextFont(text: currencies[key]["Code"]),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: currencies.keys.length, //snapshot.data?.length
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: 60)),
            // SliverToBoxAdapter(
            //   child: KeyboardHeightAreaAnimated(),
            // ),
          ],
        ),
      ),
    );
  }
}
