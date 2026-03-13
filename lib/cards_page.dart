import 'package:flutter/material.dart';

class TransitCard {
  final String name;
  final String type;
  final Color color;
  final IconData iconInfo;
  final List<String> promotions;

  const TransitCard({
    required this.name,
    required this.type,
    required this.color,
    required this.iconInfo,
    required this.promotions,
  });
}

class CardsPage extends StatefulWidget {
  const CardsPage({super.key});

  @override
  State<CardsPage> createState() => _CardsPageState();
}

class _CardsPageState extends State<CardsPage> {
  final List<TransitCard> allAvailableCards = [
    const TransitCard(
      name: 'Rabbit Card',
      type: 'BTS / BRT / Yellow / Pink',
      color: Colors.orange,
      iconInfo: Icons.directions_transit,
      promotions: ['Monthly Trip Pass', 'One Day Pass'],
    ),
    const TransitCard(
      name: 'MRT Card',
      type: 'MRT Blue / MRT Purple',
      color: Colors.blue,
      iconInfo: Icons.subway,
      promotions: [
        'Line Fare Discount',
        'Transfer Discount: Yellow (Lat Phrao) to Blue - 14 Baht',
        'Transfer Discount: Blue to Yellow (Lat Phrao) - 15 Baht',
      ],
    ),
    const TransitCard(
      name: 'EMV Contactless',
      type: 'All Supported Transit',
      color: Colors.deepPurple,
      iconInfo: Icons.credit_card,
      promotions: [
        'Transfer Discount: Yellow (Lat Phrao) to Blue - 14 Baht',
        'Transfer Discount: Blue to Yellow (Lat Phrao) - 15 Baht',
        'Transfer Discount: Pink (Nonthaburi Civic Center) to Purple - 14 Baht',
        'Transfer Discount: Purple to Pink (Nonthaburi Civic Center) - 15 Baht',
      ],
    ),
  ];

  final List<TransitCard> myCards = [];

  void _addCard(TransitCard card) {
    if (!myCards.contains(card)) {
      setState(() {
        myCards.add(card);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('\${card.name} added to your cards!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You already have \${card.name}.')),
      );
    }
  }

  void _removeCard(TransitCard card) {
    setState(() {
      myCards.remove(card);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('\${card.name} removed from your cards.')),
    );
  }

  void _showAddCardDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          builder: (context, scrollController) {
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Add a Transit Card',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: allAvailableCards.length,
                    itemBuilder: (context, index) {
                      final card = allAvailableCards[index];
                      final hasCard = myCards.contains(card);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: card.color.withAlpha(51),
                          child: Icon(card.iconInfo, color: card.color),
                        ),
                        title: Text(card.name),
                        subtitle: Text(card.type),
                        trailing: hasCard
                            ? const Icon(Icons.check, color: Colors.green)
                            : IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                color: Theme.of(context).primaryColor,
                                onPressed: () {
                                  Navigator.pop(context);
                                  _addCard(card);
                                },
                              ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Transit Cards'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddCardDialog,
          ),
        ],
      ),
      body: myCards.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.credit_card_off,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No cards added yet.',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _showAddCardDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Card'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: myCards.length,
              itemBuilder: (context, index) {
                final card = myCards[index];
                return Dismissible(
                  key: ValueKey(card.name),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => _removeCard(card),
                  background: Container(
                    padding: const EdgeInsets.only(right: 20),
                    alignment: Alignment.centerRight,
                    color: Colors.red,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: card.color.withAlpha(51),
                        child: Icon(card.iconInfo, color: card.color),
                      ),
                      title: Text(
                        card.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(card.type),
                      children: [
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Promotions & Discounts',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...card.promotions.map(
                                (promo) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4.0),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.local_offer,
                                        size: 16,
                                        color: Colors.green,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(promo)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
