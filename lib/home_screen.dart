import 'package:chatapp/chat_provider.dart';
import 'package:chatapp/login_screen.dart';
import 'package:chatapp/search_screen.dart';
import 'package:chatapp/widgets/chat_tile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = FirebaseAuth.instance;

  User? loggedInUser;

  @override
  void initState() {
    super.initState();
    getCurrentUser();
  }

  void getCurrentUser() {
    // try {
    final user = _auth.currentUser;
    if (user != null) {
      loggedInUser = user;
    }
    // } catch (e) {
    //   print(e);
    // }
  }

  Future<Map<String, dynamic>> _fetchChatData(String chatId) async {
    final chatDoc =
        await FirebaseFirestore.instance.collection('chats').doc(chatId).get();
    final chatData = chatDoc.data();
    final users = chatData!['users'] as List<dynamic>?;
    final receiverId = users!.firstWhere((id) => id != loggedInUser!.uid);
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(receiverId)
        .get();
    final userData = userDoc.data()!;
    return {
      'chatId': chatId,
      'lastMessage': chatData['lastMessage'] ?? 'No messages yet',
      'timestamp': chatData['timestamp']?.toDate() ?? DateTime.now(),
      'userData': userData,
    };
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text("Chats"),
          actions: [
            IconButton(
              onPressed: () {
                _auth.signOut();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LoginScreen(),
                  ),
                );
              },
              icon: Icon(Icons.logout),
            )
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: loggedInUser != null
                    ? chatProvider.getChats(loggedInUser!.uid)
                    : const Stream.empty(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final chatDocs = snapshot.data!.docs;

                  return FutureBuilder<List<Map<String, dynamic>>>(
                    future: Future.wait(
                      chatDocs.map(
                        (chatDoc) async {
                          final chatData = await _fetchChatData(chatDoc.id);
                          return chatData;
                        },
                      ),
                    ),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final chatDataList = snapshot.data!;

                      return ListView.builder(
                        itemCount: chatDataList.length,
                        itemBuilder: (context, index) {
                          final chatData = chatDataList[index];

                          return ChatTile(
                            chatId: chatData['chatId'],
                            lastMessage: chatData['lastMessage'],
                            timestamp: chatData['timestamp'],
                            receiverData: chatData['userData'],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            )
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Color(0xFF3876FD),
          foregroundColor: Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SearchScreen(),
              ),
            );
          },
          child: Icon(Icons.search),
        ),
      ),
    );
  }
}
