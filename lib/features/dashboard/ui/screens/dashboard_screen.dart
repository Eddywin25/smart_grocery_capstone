import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_grocery/features/inventory/ui/providers/inventory_provider.dart';
import 'package:smart_grocery/features/inventory/data/repos/food_history_repo.dart';
import 'package:smart_grocery/features/inventory/domain/models/inventory_item.dart';
import 'package:smart_grocery/shared/utilities/string_display_utility.dart';


// Dashboard screen
class DashboardScreen extends ConsumerStatefulWidget {

  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen>
    createState() =>
      _DashboardScreenState();
}

// Class used to manage dashboard screen state
class _DashboardScreenState
    extends ConsumerState<DashboardScreen> {

    static const int maxExpiringItemsShown = 3;

    bool _showAllExpiringItems = false;

    @override
    Widget build(BuildContext context) {

    final inventory = ref.watch(inventoryProvider); // Grocery inventory

    final totalInventoryCount = inventory.length;   // Number of groceries in inventory

    // Items approaching expiry
    final expiringItems =
    inventory.where(
      (item) => item.expiresSoon,
    ).toList();

    // Sort items
    expiringItems.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

    // Show abreviated list of expiring items, or show
    final shownExpiringItems =
      _showAllExpiringItems
          ? expiringItems
          : expiringItems
              .take(maxExpiringItemsShown)
              .toList();

    // Number of groceries expiring soon
    final expiringSoonCount = expiringItems.length;


    // Percentage of groceries that aren't expiring soon
    final percentFresh =
    totalInventoryCount == 0
        ? 100
        : (((totalInventoryCount -
                expiringSoonCount) /
            totalInventoryCount) *
          100).round();

    // Load history repository
    final foodHistory =
      FoodHistoryRepository()
        .loadHistory();

    // Number of groceries that have been spoiled
    final spoiledCount =
      foodHistory.where(
        (event) =>
            event.outcome ==
            FoodItemOutcome.spoiled,
      ).length;


return Scaffold(
    appBar: AppBar(
      title: const Text(
        'Grocery Dashboard',
      ),
    ),

    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          const Text(
            'Inventory Summary',
            style: TextStyle(
              fontSize: 22,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 16,
          ),

          Container(
            width: double.infinity,

            padding: const EdgeInsets.all(24),

            decoration: BoxDecoration(
              color: const Color(0xFF0D6F06), // Color(0xFF254F3D),
              borderRadius: BorderRadius.circular(24),
            ),

            // Inventory Overview Information
            child: Row(
              children: [

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [

                      const Text(
                        'YOUR KITCHEN',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),

                      // Space
                      const SizedBox(height: 16),

                      // Display Inventory Count
                      Text(
                        'You have $totalInventoryCount ${totalInventoryCount.itemReference()} currently',
                        style: const TextStyle(
                          fontSize: 28,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      // Space
                      const SizedBox(height: 12),

                      // Display number of items close to expiry
                      Text(
                        '$expiringSoonCount ${expiringSoonCount.itemReference()}'
                        ' ${expiringSoonCount.needReference()} your attention',
                        style: TextStyle(
                          color: Colors.yellow.shade200,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                // Space for Percent Freshness Radial Dial
                SizedBox(
                  width: 90,
                  height: 90,

                  child: Stack(
                    alignment: Alignment.center,

                    children: [

                      SizedBox(
                        width: 90,
                        height: 90,

                        // Radial dial for % fresh food
                        child: CircularProgressIndicator(
                          value: percentFresh / 100,
                          strokeWidth: 6,
                          backgroundColor:Colors.white24,
                          valueColor:
                              AlwaysStoppedAnimation(
                                Colors.yellow.shade400,
                              ),
                        ),
                      ),

                      // Display freshness percentages within radial dial
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$percentFresh%',

                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),

                          const Text(
                            'fresh',
                            style: TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),

          // Space
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,

            children: [

              // Header for items that will expire soon
              const Text(
                'Expiring Soon',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              // Display button to show all or show less items that are expiring soon
              if (expiringItems.length > maxExpiringItemsShown)
                TextButton(
                  onPressed: () {

                    setState(() {
                      _showAllExpiringItems =
                          !_showAllExpiringItems;
                    });

                  },

                  child: Text(
                    _showAllExpiringItems
                        ? 'Show Less'
                        : 'See All',
                  ),
                ),
            ],
          ),

          Container(
            width: double.infinity,

            decoration: BoxDecoration(
              color: Colors.white,

              borderRadius:
                  BorderRadius.circular(24),

              border: Border.all(
                color: Colors.grey.shade300,
                width: 3,
              ),
            ),

            child: 

              // List all items approaching expiry and days until expiry
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: shownExpiringItems.length,
                itemBuilder: (context, index) {
                  final item = shownExpiringItems[index];

                  return ListTile(
                    title: Text(
                      item.displayItemName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    subtitle: Text(
                      '${item.displayQuantPackage} in '
                      '${item.displayItemLocation}',
                    ),

                    trailing: Text(
                      item.expiryTime,
                        style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      )
                    ),
                  );
                },

                separatorBuilder:
                    (context, index) =>
                        const Divider(
                          height: 1,
                        ),
              ),
          ),

          // Space
          const SizedBox(height: 24),

          // Heading for Inventory Insights
          const Text(
            'Inventory Insights',
            style: TextStyle(
              fontSize: 20,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );
  }
}